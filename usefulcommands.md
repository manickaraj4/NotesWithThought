Find IP assigned on inside pod namespace:
```
for netns in $( ip netns list | cut -d " " -f 1); do echo "${netns} ==============" ; ip netns exec "${netns}" ip a ; arp -n ; ip route show ;echo "=========="; done
```

netshoot container deployment yaml:
```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-netshoot
  labels:
      app: nginx-netshoot
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-netshoot
  template:
    metadata:
      labels:
        app: nginx-netshoot
    spec:
      containers:
      - name: nginx
        image: nginx:1.14.2
        ports:
            - containerPort: 80
      - name: netshoot
        image: nicolaka/netshoot
        command: ["/bin/bash"]
        args: ["-c", "while true; do ping -c1 localhost; sleep 60;done"]
```
