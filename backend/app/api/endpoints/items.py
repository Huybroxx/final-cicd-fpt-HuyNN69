from typing import List, Optional
from datetime import datetime, timezone
from fastapi import APIRouter, HTTPException, status, Query
from app.models.item import ItemCreate, ItemUpdate, ItemResponse

router = APIRouter(prefix="/items", tags=["Items"])

_DB: dict[int, dict] = {
    1: {
        "id": 1,
        "title": "DevOps Handbook",
        "description": "Continuous delivery and automated pipelines guide",
        "price": 39.99,
        "is_active": True,
        "created_at": datetime.now(timezone.utc),
    },
    2: {
        "id": 2,
        "title": "System Design Guide",
        "description": "Scalable web applications and microservices architecture",
        "price": 29.50,
        "is_active": True,
        "created_at": datetime.now(timezone.utc),
    },
}
_CURRENT_ID = 2


def reset_db():
    global _CURRENT_ID
    _DB.clear()
    _DB[1] = {
        "id": 1,
        "title": "DevOps Handbook",
        "description": "Continuous delivery and automated pipelines guide",
        "price": 39.99,
        "is_active": True,
        "created_at": datetime.now(timezone.utc),
    }
    _DB[2] = {
        "id": 2,
        "title": "System Design Guide",
        "description": "Scalable web applications and microservices architecture",
        "price": 29.50,
        "is_active": True,
        "created_at": datetime.now(timezone.utc),
    }
    _CURRENT_ID = 2


@router.get("", response_model=List[ItemResponse], status_code=status.HTTP_200_OK)
def list_items(
    search: Optional[str] = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(10, ge=1, le=100),
) -> List[ItemResponse]:
    items = list(_DB.values())
    if search:
        search_lower = search.lower()
        items = [i for i in items if search_lower in i["title"].lower()]
    return [ItemResponse(**item) for item in items[skip : skip + limit]]


@router.post("", response_model=ItemResponse, status_code=status.HTTP_201_CREATED)
def create_item(payload: ItemCreate) -> ItemResponse:
    global _CURRENT_ID
    _CURRENT_ID += 1
    new_item = {
        "id": _CURRENT_ID,
        **payload.model_dump(),
        "created_at": datetime.now(timezone.utc),
    }
    _DB[_CURRENT_ID] = new_item
    return ItemResponse(**new_item)


@router.get("/{item_id}", response_model=ItemResponse, status_code=status.HTTP_200_OK)
def get_item(item_id: int) -> ItemResponse:
    if item_id not in _DB:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Item {item_id} not found",
        )
    return ItemResponse(**_DB[item_id])


@router.put("/{item_id}", response_model=ItemResponse, status_code=status.HTTP_200_OK)
def update_item(item_id: int, payload: ItemUpdate) -> ItemResponse:
    if item_id not in _DB:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Item {item_id} not found",
        )
    item = _DB[item_id]
    update_data = payload.model_dump(exclude_unset=True)
    item.update(update_data)
    _DB[item_id] = item
    return ItemResponse(**item)


@router.delete("/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_item(item_id: int) -> None:
    if item_id not in _DB:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Item {item_id} not found",
        )
    del _DB[item_id]
