#!/bin/bash

# 설정 변수
WATCH_DIR="/home/ubuntu/S3"  # S3가 마운트된 디렉토리 경로으로 변경하세요
TARGET_JAR="step18_empApp-0.0.1-SNAPSHOT.jar"  # 모니터링할 JAR 파일 이름
JAVA_CMD="java -jar $WATCH_DIR/$TARGET_JAR"  # 실행할 Java 명령
PID_FILE="/tmp/empApp.pid"  # Java 애플리케이션 PID를 저장할 파일 경로

# Java 애플리케이션 실행 함수
start_app() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Starting Java application..."
  $JAVA_CMD &
  echo $! > $PID_FILE
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Application started with PID $(cat $PID_FILE)"
}

# Java 애플리케이션 중지 함수
stop_app() {
  if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if ps -p "$PID" > /dev/null 2>&1; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') - Stopping application with PID $PID..."
      kill "$PID"
      # 프로세스가 종료될 때까지 대기
      while ps -p "$PID" > /dev/null 2>&1; do
        sleep 1
      done
      echo "$(date '+%Y-%m-%d %H:%M:%S') - Application stopped."
    fi
    rm -f "$PID_FILE"
  else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - PID file not found. Application may not be running."
  fi
}

# 초기 애플리케이션 시작
start_app

# inotifywait를 사용하여 파일 생성 또는 수정 감지
inotifywait -m -e modify,create "$WATCH_DIR/$TARGET_JAR" --format '%w%f' | while read FILE
do
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Detected change in $FILE. Restarting application..."
  
  # 애플리케이션 중지
  stop_app
  
  # 애플리케이션 시작
  start_app
done
