from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import numpy as np
from sklearn.datasets import load_iris
from sklearn.ensemble import RandomForestClassifier
import time

app = FastAPI(title="iris-classifier", version="1.0.0")

model = None
model_ready = False
model_load_seconds = 0.0

CLASSES = ["setosa", "versicolor", "virginica"]


class PredictRequest(BaseModel):
    features: list[float]  # [sepal_length, sepal_width, petal_length, petal_width]


class PredictResponse(BaseModel):
    prediction: int
    class_name: str
    confidence: float


@app.on_event("startup")
async def load_model():
    global model, model_ready, model_load_seconds
    start = time.time()
    iris = load_iris()
    model = RandomForestClassifier(n_estimators=100, random_state=42)
    model.fit(iris.data, iris.target)
    model_load_seconds = round(time.time() - start, 3)
    model_ready = True


@app.get("/health")
def health():
    # Liveness probe — is the process alive?
    return {"status": "alive"}


@app.get("/ready")
def ready():
    # Readiness probe — is the model loaded and ready to serve?
    if not model_ready:
        raise HTTPException(status_code=503, detail="Model not loaded yet")
    return {"status": "ready", "model_load_seconds": model_load_seconds}


@app.post("/predict", response_model=PredictResponse)
def predict(req: PredictRequest):
    if not model_ready:
        raise HTTPException(status_code=503, detail="Model not ready")
    features = np.array(req.features).reshape(1, -1)
    pred = int(model.predict(features)[0])
    proba = model.predict_proba(features)[0]
    return PredictResponse(
        prediction=pred,
        class_name=CLASSES[pred],
        confidence=round(float(proba[pred]), 4),
    )
