import os
import sys
import psycopg2
import requests
from psycopg2.extras import RealDictCursor, Json
from psycopg2.pool import SimpleConnectionPool
from flask import Flask, request, jsonify
from dotenv import load_dotenv
from functools import wraps
import logging

logging.basicConfig(level=logging.INFO)
log = logging.getLogger(__name__)

load_dotenv()

app = Flask(__name__)

DATABASE_URL = os.getenv("DATABASE_URL")
AUTH_SERVICE_URL = os.getenv("AUTH_SERVICE_URL")

if not DATABASE_URL or not AUTH_SERVICE_URL:
    log.critical("Erro: DATABASE_URL e AUTH_SERVICE_URL devem ser definidos.")
    sys.exit(1)

try:
    pool = SimpleConnectionPool(1, 5, dsn=DATABASE_URL)
    log.info("Pool de conexões com o PostgreSQL (targeting) inicializado.")
except psycopg2.OperationalError as e:
    log.critical(f"Erro fatal ao conectar ao PostgreSQL: {e}")
    sys.exit(1)


def require_auth(f):
    """Middleware para validar a chave de API contra o auth-service."""

    @wraps(f)
    def decorated(*args, **kwargs):
        auth_header = request.headers.get("Authorization")
        if not auth_header:
            return jsonify({"error": "Authorization header obrigatório"}), 401

        try:
            validate_url = f"{AUTH_SERVICE_URL}/validate"
            response = requests.get(
                validate_url,
                headers={"Authorization": auth_header},
                timeout=3,
            )

            if response.status_code != 200:
                log.warning(
                    "Falha na validação da chave (status: %s)",
                    response.status_code,
                )
                return jsonify({"error": "Chave de API inválida"}), 401
        except requests.exceptions.Timeout:
            log.error("Timeout ao conectar com o auth-service")
            return jsonify({"error": "Serviço de autenticação indisponível (timeout)"}), 504
        except requests.exceptions.RequestException as e:
            log.error("Erro ao conectar com o auth-service: %s", e)
            return jsonify({"error": "Serviço de autenticação indisponível"}), 503

        return f(*args, **kwargs)

    return decorated


@app.route('/health')
def health():
    return jsonify({"status": "ok"})


@app.route('/rules', methods=['POST'])
@require_auth
def create_rule():
    data = request.get_json()
    if not data or 'flag_name' not in data or 'rules' not in data:
        return jsonify({"error": "'flag_name' e 'rules' (JSON) são obrigatórios"}), 400

    flag_name = data['flag_name']
    rules_obj = data['rules']
    is_enabled = data.get('is_enabled', True)

    conn = None
    cur = None
    try:
        conn = pool.getconn()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute(
            "INSERT INTO targeting_rules (flag_name, is_enabled, rules, created_at, updated_at) "
            "VALUES (%s, %s, %s, NOW(), NOW()) RETURNING *",
            (flag_name, is_enabled, Json(rules_obj)),
        )
        new_rule = cur.fetchone()
        conn.commit()
        log.info("Regra para '%s' criada com sucesso.", flag_name)
        return jsonify(new_rule), 201
    except psycopg2.IntegrityError:
        if conn:
            conn.rollback()
        log.warning("Tentativa de criar regra duplicada: '%s'", flag_name)
        return jsonify({"error": f"Regra para a flag '{flag_name}' já existe"}), 409
    except Exception as e:
        if conn:
            conn.rollback()
        log.error("Erro ao criar regra: %s", e)
        return jsonify({"error": "Erro interno do servidor", "details": str(e)}), 500
    finally:
        if cur:
            cur.close()
        if conn:
            pool.putconn(conn)


@app.route('/rules/<string:flag_name>', methods=['GET'])
@require_auth
def get_rule(flag_name):
    conn = None
    cur = None
    try:
        conn = pool.getconn()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute(
            "SELECT * FROM targeting_rules WHERE flag_name = %s",
            (flag_name,),
        )
        rule = cur.fetchone()
        if not rule:
            return jsonify({"error": "Regra não encontrada"}), 404
        return jsonify(rule)
    except Exception as e:
        log.error("Erro ao buscar regra '%s': %s", flag_name, e)
        return jsonify({"error": "Erro interno do servidor", "details": str(e)}), 500
    finally:
        if cur:
            cur.close()
        if conn:
            pool.putconn(conn)


@app.route('/rules/<string:flag_name>', methods=['PUT'])
@require_auth
def update_rule(flag_name):
    """Atualiza campos permitidos usando apenas SQL estático parametrizado."""
    data = request.get_json()
    if not data:
        return jsonify({"error": "Corpo da requisição obrigatório"}), 400

    has_rules = 'rules' in data
    has_is_enabled = 'is_enabled' in data

    if not has_rules and not has_is_enabled:
        return jsonify({
            "error": "Pelo menos um campo ('rules', 'is_enabled') é obrigatório"
        }), 400

    conn = None
    cur = None
    try:
        conn = pool.getconn()
        cur = conn.cursor(cursor_factory=RealDictCursor)

        if has_rules and has_is_enabled:
            cur.execute(
                "UPDATE targeting_rules SET rules = %s, is_enabled = %s, updated_at = NOW() "
                "WHERE flag_name = %s RETURNING *",
                (Json(data['rules']), data['is_enabled'], flag_name),
            )
        elif has_rules:
            cur.execute(
                "UPDATE targeting_rules SET rules = %s, updated_at = NOW() "
                "WHERE flag_name = %s RETURNING *",
                (Json(data['rules']), flag_name),
            )
        else:
            cur.execute(
                "UPDATE targeting_rules SET is_enabled = %s, updated_at = NOW() "
                "WHERE flag_name = %s RETURNING *",
                (data['is_enabled'], flag_name),
            )

        if cur.rowcount == 0:
            return jsonify({"error": "Regra não encontrada"}), 404

        updated_rule = cur.fetchone()
        conn.commit()
        log.info("Regra para '%s' atualizada com sucesso.", flag_name)
        return jsonify(updated_rule), 200
    except Exception as e:
        if conn:
            conn.rollback()
        log.error("Erro ao atualizar regra '%s': %s", flag_name, e)
        return jsonify({"error": "Erro interno do servidor", "details": str(e)}), 500
    finally:
        if cur:
            cur.close()
        if conn:
            pool.putconn(conn)


@app.route('/rules/<string:flag_name>', methods=['DELETE'])
@require_auth
def delete_rule(flag_name):
    conn = None
    cur = None
    try:
        conn = pool.getconn()
        cur = conn.cursor()
        cur.execute(
            "DELETE FROM targeting_rules WHERE flag_name = %s",
            (flag_name,),
        )

        if cur.rowcount == 0:
            return jsonify({"error": "Regra não encontrada"}), 404

        conn.commit()
        log.info("Regra para '%s' deletada com sucesso.", flag_name)
        return "", 204
    except Exception as e:
        if conn:
            conn.rollback()
        log.error("Erro ao deletar regra '%s': %s", flag_name, e)
        return jsonify({"error": "Erro interno do servidor", "details": str(e)}), 500
    finally:
        if cur:
            cur.close()
        if conn:
            pool.putconn(conn)


if __name__ == '__main__':
    port = int(os.getenv("PORT", 8003))
    app.run(host='0.0.0.0', port=port, debug=False)
