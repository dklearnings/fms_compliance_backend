from fastapi.responses import JSONResponse

SQLSTATE_HTTP_MAP = {
    "23P01": 409,
    "22023": 400
}

def problem_response(
    request,
    status: int,
    title: str,
    detail: str,
    type_url: str
):

    return JSONResponse(
        status_code=status,
        content={
            "type": type_url,
            "title": title,
            "status": status,
            "detail": detail,
            "instance": str(request.url)
        }
    )