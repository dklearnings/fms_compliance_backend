from pydantic import BaseModel


class ProductRequest(BaseModel):

    product_name: str
    price: float
    stock_quantity: int


class OrderRequest(BaseModel):

    customer_name: str
    product_id: int
    quantity: int