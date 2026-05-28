from psycopg_pool import ConnectionPool

# Database configuration (keep simple defaults; override via env if needed)
DB_CONFIG = {
    "host": "database-fms.ctqq62860gae.ap-south-2.rds.amazonaws.com",
    "port": 5432,
    "database": "postgres",
    "user": "postgres",
    "password": "sasabestrong"
}

_CONNINFO = (
    f"host={DB_CONFIG['host']} port={DB_CONFIG['port']} dbname={DB_CONFIG['database']} "
    f"user={DB_CONFIG['user']} password={DB_CONFIG['password']}"
)

# Expose a connection pool compatible with callers using `with pool.connection() as conn:`
pool = ConnectionPool(conninfo=_CONNINFO)

def get_connection():
    """Return a single connection (context-managed) from the pool."""
    return pool.connection()