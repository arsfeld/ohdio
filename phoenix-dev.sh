#!/bin/bash
# Helper script for Phoenix development with Docker Compose

set -e

COMPOSE_FILE="compose.phoenix.yml"

case "$1" in
  start)
    echo "Starting Phoenix development environment..."
    docker compose -f $COMPOSE_FILE up -d
    echo "Phoenix server starting at http://localhost:4000"
    ;;

  stop)
    echo "Stopping Phoenix development environment..."
    docker compose -f $COMPOSE_FILE down
    ;;

  restart)
    echo "Restarting Phoenix development environment..."
    docker compose -f $COMPOSE_FILE restart
    ;;

  logs)
    docker compose -f $COMPOSE_FILE logs -f phoenix
    ;;

  shell)
    echo "Opening shell in Phoenix container..."
    docker compose -f $COMPOSE_FILE exec phoenix bash
    ;;

  iex)
    echo "Opening IEx console..."
    docker compose -f $COMPOSE_FILE exec phoenix iex -S mix
    ;;

  mix)
    shift
    docker compose -f $COMPOSE_FILE exec phoenix mix "$@"
    ;;

  clean)
    echo "Cleaning up all Phoenix containers and volumes..."
    read -p "This will delete all data. Are you sure? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      docker compose -f $COMPOSE_FILE down -v
      echo "Cleanup complete."
    fi
    ;;

  build)
    echo "Building Phoenix Docker image..."
    docker compose -f $COMPOSE_FILE build
    ;;

  *)
    echo "OHdio Phoenix Development Helper"
    echo ""
    echo "Usage: $0 {start|stop|restart|logs|shell|iex|mix|clean|build}"
    echo ""
    echo "Commands:"
    echo "  start    - Start the Phoenix development environment"
    echo "  stop     - Stop the Phoenix development environment"
    echo "  restart  - Restart the Phoenix server"
    echo "  logs     - Follow Phoenix logs"
    echo "  shell    - Open a bash shell in the container"
    echo "  iex      - Open an IEx console with the app loaded"
    echo "  mix      - Run mix commands (e.g., ./phoenix-dev.sh mix ecto.migrate)"
    echo "  clean    - Remove all containers and volumes (WARNING: deletes data)"
    echo "  build    - Rebuild the Docker image"
    echo ""
    echo "Examples:"
    echo "  $0 start"
    echo "  $0 logs"
    echo "  $0 mix ecto.migrate"
    echo "  $0 iex"
    exit 1
    ;;
esac
