from fastapi import FastAPI, HTTPException, Depends, Query

from database import get_connection
from auth import verify_api_key
from models import ProductRequest, OrderRequest
from logger_config import logger

import psycopg2

app = FastAPI(
    title="Ecommerce REST API"
)

# =====================================================
# CREATE PRODUCT
# =====================================================

@app.post("/products")
def create_product(
    request: ProductRequest,
    api_key: str = Depends(verify_api_key)
):

    conn = None

    try:

        conn = get_connection()

        cursor = conn.cursor()

        cursor.execute(
            """
            CALL sp_create_product(%s,%s,%s)
            """,
            (
                request.product_name,
                request.price,
                request.stock_quantity
            )
        )

        conn.commit()

        logger.info(
            f"Product created: {request.product_name}"
        )

        return {
            "success": True,
            "message": "Product created successfully"
        }

    except psycopg2.Error as ex:

        if conn:
            conn.rollback()

        logger.error(str(ex))

        raise HTTPException(
            status_code=500,
            detail="Database error"
        )

    finally:

        if conn:
            conn.close()

# =====================================================
# GET PRODUCTS
# =====================================================

@app.get("/products")
def get_products(
    page: int = Query(1, ge=1),
    size: int = Query(10, ge=1),
    sort_by: str = "product_id",
    order: str = "asc",
    api_key: str = Depends(verify_api_key)
):

    conn = None

    try:

        allowed_columns = [
            "product_id",
            "product_name",
            "price",
            "stock_quantity"
        ]

        if sort_by not in allowed_columns:

            raise HTTPException(
                status_code=400,
                detail="Invalid sort column"
            )

        offset = (page - 1) * size

        conn = get_connection()

        cursor = conn.cursor()

        query = f"""
        SELECT *
        FROM products
        ORDER BY {sort_by} {order}
        LIMIT %s OFFSET %s
        """

        cursor.execute(query, (size, offset))

        result = cursor.fetchall()

        return {
            "page": page,
            "size": size,
            "data": result
        }

    finally:

        if conn:
            conn.close()

# =====================================================
# CREATE ORDER
# =====================================================

@app.post("/orders")
def create_order(
    request: OrderRequest,
    api_key: str = Depends(verify_api_key)
):

    conn = None

    try:

        conn = get_connection()

        cursor = conn.cursor()

        cursor.execute(
            """
            CALL sp_create_order(%s,%s,%s)
            """,
            (
                request.customer_name,
                request.product_id,
                request.quantity
            )
        )

        conn.commit()

        logger.info(
            f"Order created for customer={request.customer_name}"
        )

        return {
            "success": True,
            "message": "Order created successfully"
        }

    except psycopg2.Error as ex:

        if conn:
            conn.rollback()

        logger.error(str(ex))

        raise HTTPException(
            status_code=500,
            detail=str(ex)
        )

    finally:

        if conn:
            conn.close()

# =====================================================
# GET ORDERS
# =====================================================

@app.get("/orders")
def get_orders(
    page: int = Query(1, ge=1),
    size: int = Query(10, ge=1),
    api_key: str = Depends(verify_api_key)
):

    conn = None

    try:

        offset = (page - 1) * size

        conn = get_connection()

        cursor = conn.cursor()

        cursor.execute(
            """
            SELECT
                o.order_id,
                o.customer_name,
                o.product_id,
                p.product_name,
                o.quantity,
                o.total_amount,
                o.order_status,
                o.created_at
            FROM orders o
            INNER JOIN products p
                ON o.product_id = p.product_id
            ORDER BY o.order_id DESC
            LIMIT %s OFFSET %s
            """,
            (
                size,
                offset
            )
        )

        result = cursor.fetchall()

        return {
            "page": page,
            "size": size,
            "data": result
        }

    finally:

        if conn:
            conn.close()