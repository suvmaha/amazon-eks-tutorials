"""
log-experiment.py

Logs a training run to MLflow and registers the resulting model.
Requires: pip install mlflow scikit-learn
MLflow UI must be port-forwarded on localhost:5000 before running.

Compatible with MLflow 3.x (artifact_path replaced by name).
"""

import mlflow
import mlflow.sklearn
from sklearn.linear_model import LogisticRegression
from sklearn.datasets import load_iris

TRACKING_URI = "http://localhost:5000"
EXPERIMENT_NAME = "iris-classification"
MODEL_NAME = "iris-classifier"

mlflow.set_tracking_uri(TRACKING_URI)
mlflow.set_experiment(EXPERIMENT_NAME)

print(f"Experiment: {EXPERIMENT_NAME}")

X, y = load_iris(return_X_y=True)

params = {"C": 0.5, "max_iter": 200}
model = LogisticRegression(**params)
model.fit(X, y)
accuracy = model.score(X, y)

with mlflow.start_run() as run:
    run_id = run.info.run_id
    mlflow.log_params(params)
    mlflow.log_metric("accuracy", round(accuracy, 4))

    mlflow.sklearn.log_model(
        model,
        name="model",
    )

    print(f"Run ID: {run_id}")
    print(f"  logged param  C = {params['C']}")
    print(f"  logged param  max_iter = {params['max_iter']}")
    print(f"  logged metric accuracy = {round(accuracy, 4)}")

# Register the model separately (MLflow 3.x pattern)
model_uri = f"runs:/{run_id}/model"
mv = mlflow.register_model(model_uri, MODEL_NAME)
print(f"  registered model: {MODEL_NAME} (Version {mv.version})")

print(f"✅  Done. Open http://localhost:5000 to see the run.")
print(f"    Go to Models → {MODEL_NAME} → Version {mv.version} → promote to Production.")
