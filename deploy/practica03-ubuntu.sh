#!/bin/bash
# =============================================================================
# PRÁCTICA 03 - Script para Ubuntu
# Conectarse a la instancia EC2 y tomar evidencia del paso 07
# =============================================================================

IP="52.90.172.64"   # Actualizar si cambia al reiniciar la instancia
LLAVE=~/llave-inventario-cloud-los-rojos.pem

# =============================================================================
# PASO 1: Crear la llave en Ubuntu
# Copia el contenido de la llave desde CloudShell (cat ~/llave-*.pem)
# y pégalo aquí entre los EOF
# =============================================================================
cat > $LLAVE << 'EOF'
-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEA9uiBgk0/wI5WaUEqkj8mSiFMi58Y9tgp/aKOYaazGtdGRHPU
+zjIup7+mAnJLQaM7FXzXzkmiKRZ9g5xU4MJFrOFheuUNvorlLJy7G87XSDD2IgI
ux59sybnM9V2OLPNKt5GHNYkrYDYfZ2Oj2Vp8Znv37nVjdhvzMpZUTd7bZvkiTyD
jIw3lsSf8rXt3AUc0E/+1JIbM9AZmcv+T5uFATilQZJ+E2W0PYSBZ8qzqjrcZZWz
UGbsAopP6KBS3OFQTLUDxrnYPMxBBk+eA0bkjKcXGOK4g/KzHaRv9JRQuB5H+iK6
0hKSAdnJCqaAs7X9eTx70ipoYH4jajSNaZk30QIDAQABAoIBAQCyGWp5vBEVa1an
W6tCjKyo4jYdrGhMfgZj/uKnS6B75va3n7nscLxR6SgKMVzczpHOU/1WHZpPDAYc
N7TFIYrnxhy1SgXCVlgjTUkahO2UMnMyeIWbu9W96XzyZbJ+GiwPFQAMAue4A22l
xoWzp9pwvLJLdfe19n5GgVtF+zhcCaFueh3B2h2nqXK0ZCcgCrfhGmk+YVhS+v2D
2TuuJhdx+V4+n1uFg/P2Hm8crSHkrFpF7L10RNHyOJE0jcfJfx7I3HhDjzOKY7Po
Ra3VH9h+wTh8gfQk90bdcJPDA/epyXT123EeqUd7T22xoUpQJ++RK+lhx6MhZPSY
c7cgkExVAoGBAPw19r45nXnKtJ3CAZ6E7VgBX6Nxtpvd2UDijKgt4eqzSzIR1Dzn
84nV1Tv+jDbWauRnbiQs6Aoi2rLmnu/gGWFGPxbxgV5jmk6xQS0846Lg+C7KOlVG
3Wrey0kOtpRbM6uCNP7t32Go69dfVdalqIKdqoj6+yp4gkPEHtK2diYjAoGBAPqe
Jc19kBxbFj1ZM3yYYvjjhshkl7GAen249cQZaIP0c17V7SEL6OfP4Rt9gcwgHmkQ
WZx3PhpKa3mbZTeEUob9sRp6j0XQg1JPBqRQXgQ67oPPg4LPgE0ke+HZVMGUSw9d
REV78QBrFm9Bn6yx9pXWHqLwTmb53s3XQ/OdFVd7AoGAHvyyWCTUCEazcj6H3GYQ
kyN4EKjD+tqC+sna5j7c5u0oa/pszR7ieSjgjgJ0T7iAYZejnKY3zCcEH77eADLU
a3MqBTOe5W3vY4O7skcs4LIrS/Rkvl16jsrYxx0bqZaa/pN812V6cJFEiK2Z6klo
LsQYU8QiX9F2j8Tk1Ja+ZWkCgYBkGzu6Y0dnLDMr+i+Iu039YNT7wsKdElbbVUBG
PmfzHXfgD8+SfbFgtzaRxoZMRSAgk3lX+IGD+uoHPz0k+eQFK9zMWNxV5L4v6IUc
qUWEpw2S9Rbw73WuWr5pLmiekl+RGY4luyY/JodllW70inmWzFqcdyS6GWEYE75+
1uYpdQKBgHUIgOi1cMfxMed3J03OKCm8F15ZN5ehI+BxKnN+wjlyWc8TMIDAC+3m
IbnkT3Gj4ICvYNa7kGJfO8TtdM2uST9NpN0/vXcgGF8abVRQCy2PeXOqL8HJScIE
cpIP4L01LUlAtxJJoDCWyj0dV++1y8TEx6kg5Fbdc1wrYNAsxsC+
-----END RSA PRIVATE KEY-----
EOF

chmod 400 $LLAVE
echo "✔ Llave lista: $LLAVE"

# =============================================================================
# PASO 2: Conectarse y ejecutar evidencia
# =============================================================================
echo "Conectando a $IP..."
ssh -o StrictHostKeyChecking=accept-new -i $LLAVE ec2-user@$IP \
  'echo "=== PASO 07: Conexión SSH ===" && uname -a && echo "" && cat /etc/os-release && echo "" && echo "Proyecto : inventario-cloud" && echo "Equipo   : Los Rojos" && echo "Servidor : $(hostname)" && echo "IP       : $(curl -s https://checkip.amazonaws.com)"'
