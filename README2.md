
                        [Internet]
                            |
                            | HTTP/HTTPS
                            v
                  +-------------------+
                  | Internet Gateway  |  <-- conecta VPC à Internet
                  +-------------------+
                            |
                            v
                  +-------------------+
                  | Public Subnets    |  <-- Subnets públicas
                  | Route Table:      |
                  | 0.0.0.0/0 → IGW   |  <-- toda saída p/ Internet
                  +-------------------+
                            |
                            v
                   +-------------------+
                   | Load Balancer     |  <-- ALB criado pelo AWS LB Controller
                   | (IP público)      |
                   +-------------------+
                            |
                            v
                   +-------------------+
                   | Ingress Controller|  <-- lê rules do Ingress
                   +-------------------+
                            |
          +-----------------+------------------+
          |                                    |
          v                                    v
  path /nginx -> Service nginx         path /grafana -> Service grafana
          |                                    |
          v                                    v
  +----------------+                   +----------------+
  | Pods nginx     |                   | Pods grafana   |
  | (Private Sub)  |                   | (Private Sub)  |
  +----------------+                   +----------------+

