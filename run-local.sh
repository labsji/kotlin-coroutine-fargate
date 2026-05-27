#!/bin/bash
# run-local.sh — Build and run the coroutine lab app in CloudShell
set -e
cd "$(dirname "$0")"

# Install Gradle wrapper if missing
if [ ! -f gradlew ]; then
  echo "Downloading Gradle wrapper..."
  gradle_ver="8.5"
  curl -fsSL "https://services.gradle.org/distributions/gradle-${gradle_ver}-bin.zip" -o /tmp/gradle.zip
  unzip -qo /tmp/gradle.zip -d /tmp
  /tmp/gradle-${gradle_ver}/bin/gradle wrapper --gradle-version ${gradle_ver} -q
fi

echo "Building..."
./gradlew shadowJar -q 2>&1 | tail -3

echo "Starting Kotlin Coroutine Lab on port 8080..."
echo ""
echo "  Endpoints:"
echo "    curl localhost:8080/lab/1              # Dispatchers.Default"
echo "    curl localhost:8080/lab/2              # Dispatchers.IO"
echo "    curl localhost:8080/lab/3?parallelism=4 # limitedParallelism"
echo "    curl localhost:8080/lab/4?permits=10   # Semaphore"
echo "    curl localhost:8080/metrics            # CPU, threads, memory"
echo ""
echo "  Press Ctrl+C to stop."
echo ""

java -jar build/libs/*-all.jar
