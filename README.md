# 📘 개요

Jenkins와 AWS를 사용하여 CI/CD 파이프라인을 구현하고, EC2와 S3를 활용한 배포 환경을 구축하는 것을 목표로 합니다. 이를 통해 자동화된 배포 프로세스를 구축하고 인프라 관리의 효율성을 높였습니다.

<h1 style="font-size: 25px;"> 👨‍👨‍👧‍👦💻 팀원 <br>
<br>
    
|<img src="https://avatars.githubusercontent.com/u/64997345?v=4" width="120" height="120"/>|<img src="https://avatars.githubusercontent.com/u/38968449?v=4" width="120" height="120"/>
|:-:|:-:|
|[@최영하](https://github.com/ChoiYoungha)|[@허예은](https://github.com/yyyeun)

</h1>

# 🎯 목적

목적은 DevOps 도구인 Jenkins와 AWS의 다양한 서비스를 활용하여 CI/CD 환경을 구축하고, 이를 통해 개발과 배포의 효율성을 향상시키는 것입니다.

# 🦄 아키텍처
![다운로드2](https://github.com/user-attachments/assets/c2b0d6b2-d3ff-4710-aef1-9f4568d4b175)


# 🛠 작업 프로세스

## 🌿 Spring Property 설정 (RDS 정보 은닉)
RDS 접속 정보를 안전하게 보호하기 위해 Spring Property 파일에서 민감한 정보를 은닉하였습니다.

`application.properties`
```
# MySQL DataSource configuration
spring.datasource.driver-class-name=com.mysql.cj.jdbc.Driver
spring.datasource.url=${DB_URL}
spring.datasource.username=${DB_USERNAME}
spring.datasource.password=${DB_PASSWORD}
```

**실행 환경에서 환경 변수 설정**

```bash
# ~/.bashrc 파일 수정
$ nano ~/.bashrc

# 파일 하단에 DB 관련 환경 변수 추가
export DB_URL="db_url"
export DB_USERNAME="username"
export DB_PASSWORD="password"

# 변경 사항 적용
$ source ~/.bashrc
```

## 🖥️ Jenkins 컨테이너 AWS CLI 설치


```shell
docker exec -it {container_id} bash
$ curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-2.0.30.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```


Jenkins 컨테이너 내에 AWS CLI를 설치하여, Jenkins 파이프라인에서 AWS 자원을 손쉽게 사용할 수 있도록 준비했습니다.

## 📝 Jenkins 파이프라인 작성

**Jenkins AWS Credentials 생성**
![2024-10-11 16 55 50](https://github.com/user-attachments/assets/42acdcb8-9f66-4872-8bad-8b9ee9e8b407)


**Pipline code**
```shell
pipeline {
    agent any

    stages {
        stage('Clone Repository') {
            steps {
                git branch: 'main', url: 'https://github.com/ChoiYoungHa/Jenkins-Test.git'
                echo "다운로드"
            }
        }
         stage('Build') {
            steps {
                sh 'chmod +x gradlew'                    
                sh './gradlew clean build -x test'
                sh 'echo $WORKSPACE'
            }
        }
        stage('Copy jar') { 
            steps {
                script {
                    def jarFile = 'build/libs/step18_empApp-0.0.1-SNAPSHOT.jar'
                    def destDir = '/var/jenkins_home/appjar/'
                    def destFile = "${destDir}step18_empApp-0.0.1-SNAPSHOT.jar"
                    def backupFile = "${destDir}step18_empApp-0.0.1-SNAPSHOT.jar.bak"
                    
                    // 기존 jar 파일이 존재하는지 확인하고 백업
                    sh """
                        if [ -f "${destFile}" ]; then
                            mv "${destFile}" "${backupFile}"
                            echo "기존 jar 파일을 백업했습니다: ${backupFile}"
                        else
                            echo "백업할 기존 jar 파일이 없습니다."
                        fi
                    """
                    
                    // 새로운 jar 파일 복사
                    sh "cp ${jarFile} ${destDir}"
                    echo "새로운 jar 파일을 복사했습니다: ${destFile}"
                }
            }
        }
        stage('Upload to S3') {
            steps {
                withAWS(credentials: 'aws_key') {
                    sh '''
                        aws s3 cp /var/jenkins_home/appjar/step18_empApp-0.0.1-SNAPSHOT.jar s3://ce33-bucket-01/step18_empApp-0.0.1-SNAPSHOT.jar
                        echo "S3에 jar 파일을 업로드했습니다: s3://ce33-bucket-01/step18_empApp-0.0.1-SNAPSHOT.jar"
                    '''
                }
            }
        }
    }
}

```
Jenkins pipline을 작성하여, 코드 변경 시 자동으로 빌드하고 배포하는 CI/CD 파이프라인을 구축했습니다.



## ☁️ EC2 S3 마운트
```shell
sudo apt install -y golang fuse

go version
```

**환경변수 등록**
```shell
which go
export GOBIN=/usr/bin
go env | egrep 'GOROOT|GOBIN|GOPATH'

GOBIN="/usr/bin"
GOPATH="/root/go"
GOROOT="/usr/lib/golang"
```
**goofys 설치**
```shell
wget http://bit.ly/goofys-latest -O /usr/local/bin/goofys
chmod +x /usr/local/bin/goofys
goofys --version
```

**AWS S3 마운트**
```shell
mkdir -p /S3
goofys target-bucket ./S3
df -h
```

**결과 확인**
![2024-10-11 17 04 11](https://github.com/user-attachments/assets/65765007-fad5-40ad-8091-f716bbe0f552)
![2024-10-11 17 04 41](https://github.com/user-attachments/assets/46e1c595-4663-41bd-a6f8-7b910a2e91e2)


EC2 인스턴스를 S3에 마운트하여, 빌드된 애플리케이션을 S3에 업로드하고 이를 EC2에서 사용할 수 있도록 구성했습니다.

## 3.4 🔄 스크립트 작성 (inotify 백그라운드 실행)
```shell
#!/bin/bash

WATCH_DIR="/home/ubuntu/S3" 
TARGET_JAR="step18_empApp-0.0.1-SNAPSHOT.jar"  # 모니터링할 JAR 파일 이름
JAVA_CMD="java -jar $WATCH_DIR/$TARGET_JAR"  # 실행할 Java 명령
PID_FILE="/tmp/empApp.pid"  # Java 애플리케이션 PID를 저장할 파일 경로


start_app() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Starting Java application..."
  $JAVA_CMD &
  echo $! > $PID_FILE
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Application started with PID $(cat $PID_FILE)"
}


stop_app() {
  if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if ps -p "$PID" > /dev/null 2>&1; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') - Stopping application with PID $PID..."
      kill "$PID"

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

```

**백그라운드 실행**
```shell
nohup ./monitoring.sh > monitoring.log 2>&1 *&
```

inotify를 사용하여 파일 변경을 감지하고 자동으로 작업을 수행하는 스크립트를 작성하여 백그라운드에서 실행하도록 설정했습니다.

## 3.5 ✅ CI/CD 확인
**파일 수정**

![2024-10-11 17 24 09](https://github.com/user-attachments/assets/c7f88338-283f-4ddc-b6ab-1c563005677f)

**git push**

![2024-10-11 17 24 27](https://github.com/user-attachments/assets/4e2caff8-3451-44f4-9295-338a6e1bf940)


**파이프라인 동작 확인**

![2024-10-11 17 20 48](https://github.com/user-attachments/assets/f066c69b-f051-4fcc-8367-f2a3c3afed2f)

**S3 파일변경**

![2024-10-11 17 21 41](https://github.com/user-attachments/assets/13ed5a23-5f90-45d0-8861-4bd32af68d16)

**AWS 배포확인**

![2024-10-11 17 23 44](https://github.com/user-attachments/assets/fa44bea2-4bd9-483d-ac18-e8a7ccb5ed3e)

전체 CI/CD 파이프라인을 테스트하여, 모든 단계가 올바르게 동작하는지 확인했습니다.

# 🐞 트러블 슈팅

### 🛠 Jenkins AWS Credentials / Steps 설치
**AWS AWS Credentials 에러발생**
![2024-10-11 17 28 01](https://github.com/user-attachments/assets/e5048fd3-fcf5-45be-9bf4-6aa2a5398a4f)

**Plugin 설치**
![2024-10-11 17 27 37](https://github.com/user-attachments/assets/7a75d53d-0e76-4293-8ce6-adc51d565bd5)



Jenkins에서 AWS Credentials을 사용하는 과정에서 발생한 문제를 해결하기 위해 필요한 플러그인 설치 및 설정 과정을 진행했습니다.



# 💡 결론 및 고찰

CI/CD 파이프라인을 구축하면서 다양한 DevOps 도구와 AWS 서비스를 효과적으로 활용할 수 있는 방법을 배웠습니다. 또한 자동화된 배포 프로세스를 구축함으로써 개발과 배포의 효율성을 크게 향상시킬 수 있었습니다.
