oc run disk-check --image=busybox -i --tty --rm --overrides='
{
  "spec": {
    "containers": [
      {
        "name": "disk-check",
        "image": "busybox",
        "command": ["ls", "-R", "/mnt"],
        "volumeMounts": [{ "name": "data", "mountPath": "/mnt" }]
      }
    ],
    "volumes": [{ "name": "data", "persistentVolumeClaim": { "claimName": "hello-python-pvc" } }]
  }
}'
