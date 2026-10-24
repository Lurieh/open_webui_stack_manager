#!/bin/bash
# Script de démarrage/arrêt Docker + Ollama + Open WebUI

CONTAINER_NAME="open-webui"
IMAGE="ghcr.io/open-webui/open-webui:main"
TIMEOUT=120

wait_healthy() {
    echo ""
    echo "⏳ En attente qu'Open WebUI soit prêt..."
    local elapsed=0
    
    while [ $elapsed -lt $TIMEOUT ]; do
        local status=$(sudo docker inspect --format='{{.State.Health.Status}}' "$CONTAINER_NAME" 2>/dev/null)
        
        if [ "$status" = "healthy" ]; then
            echo ""
            echo "✅ Open WebUI est prêt et sain !"
            echo "   🌐 http://localhost:8080"
            echo "    Ollama: http://localhost:11434"
            return 0
        elif [ "$status" = "unhealthy" ]; then
            echo ""
            echo "❌ Open WebUI est marqué comme unhealthy."
            echo "Si Steam est lancé, quitte le."
            echo "Sinon, Vérifie les logs :"
            echo "   sudo docker logs $CONTAINER_NAME"
            return 1
        elif [ -z "$status" ] || [ "$status" = "<no value>" ]; then
            local running=$(sudo docker inspect --format='{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null)
            if [ "$running" != "true" ]; then
                echo ""
                echo "❌ Le container n'est pas en cours d'exécution."
                return 1
            fi
        fi
        
        printf "."
        sleep 2
        elapsed=$((elapsed + 2))
    done
    
    echo ""
    echo "⏱️  Timeout atteint ($TIMEOUT s)."
    return 1
}

case "$1" in
    start)
        echo " Vérification de Docker..."
        if ! sudo systemctl is-active --quiet docker; then
            echo "   Démarrage de Docker..."
            sudo systemctl start docker
            sleep 2
        else
            echo "   Docker est déjà actif."
        fi
        
        echo "🤖 Démarrage d'Ollama..."
        sudo systemctl start ollama
        
        echo " Démarrage d'Open WebUI..."
        if sudo docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
            sudo docker start "$CONTAINER_NAME"
        else
            sudo docker run -d \
                --name "$CONTAINER_NAME" \
                --network host \
                --device /dev/dri:/dev/dri \
                --group-add $(stat -c "%g" /dev/dri/renderD128) \
                -v open-webui-data:/app/backend/data \
                "$IMAGE"
        fi
        
        wait_healthy
        ;;
    
    stop)
        echo "🛑 Arrêt d'Open WebUI..."
        sudo docker stop "$CONTAINER_NAME" 2>/dev/null || echo "   (déjà arrêté)"
        
        echo " Arrêt d'Ollama..."
        sudo systemctl stop ollama
        
        echo "🐳 Arrêt de Docker..."
        sudo systemctl stop docker
        
        echo "✅ Tout est arrêté."
        ;;
    
    status)
        echo "📊 État des services :"
        echo ""
        echo "Docker : $(sudo systemctl is-active docker)"
        echo "Ollama : $(sudo systemctl is-active ollama)"
        echo ""
        echo "Open WebUI :"
        sudo docker ps --filter name="$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}" 2>/dev/null || echo "Docker inactif"
        ;;
    
    *)
        echo "Usage: $0 {start|stop|status}"
        exit 1
        ;;
esac
