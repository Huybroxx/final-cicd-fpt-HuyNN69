def test_list_items(client):
    response = client.get("/api/v1/items")
    assert response.status_code == 200
    items = response.json()
    assert isinstance(items, list)
    assert len(items) == 2


def test_create_item_success(client):
    payload = {
        "title": "Continuous Delivery",
        "description": "Automated deployment pipeline guide",
        "price": 35.00,
        "is_active": True,
    }
    response = client.post("/api/v1/items", json=payload)
    assert response.status_code == 201
    created = response.json()
    assert created["id"] == 3
    assert created["title"] == payload["title"]
    assert created["price"] == payload["price"]
    assert "created_at" in created


def test_create_item_validation_error(client):
    response = client.post("/api/v1/items", json={"price": 10.0})
    assert response.status_code == 422

    response = client.post(
        "/api/v1/items",
        json={"title": "Invalid Price", "price": -5.0},
    )
    assert response.status_code == 422


def test_get_item_by_id_success(client):
    response = client.get("/api/v1/items/1")
    assert response.status_code == 200
    item = response.json()
    assert item["id"] == 1
    assert item["title"] == "DevOps Handbook"


def test_get_item_not_found(client):
    response = client.get("/api/v1/items/999")
    assert response.status_code == 404
    assert "not found" in response.json()["detail"].lower()


def test_update_item_success(client):
    update_payload = {"price": 49.99, "description": "Updated Edition"}
    response = client.put("/api/v1/items/1", json=update_payload)
    assert response.status_code == 200
    updated = response.json()
    assert updated["id"] == 1
    assert updated["price"] == 49.99
    assert updated["description"] == "Updated Edition"
    assert updated["title"] == "DevOps Handbook"


def test_update_item_not_found(client):
    response = client.put("/api/v1/items/999", json={"price": 10.0})
    assert response.status_code == 404


def test_delete_item_success(client):
    response = client.delete("/api/v1/items/1")
    assert response.status_code == 204

    get_res = client.get("/api/v1/items/1")
    assert get_res.status_code == 404


def test_delete_item_not_found(client):
    response = client.delete("/api/v1/items/999")
    assert response.status_code == 404


def test_search_and_pagination(client):
    response = client.get("/api/v1/items?search=DevOps")
    assert response.status_code == 200
    results = response.json()
    assert len(results) == 1
    assert "DevOps" in results[0]["title"]

    response = client.get("/api/v1/items?skip=1&limit=1")
    assert response.status_code == 200
    page = response.json()
    assert len(page) == 1
    assert page[0]["id"] == 2
