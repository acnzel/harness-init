---
name: migrate
description: Django DB 마이그레이션 안전 절차
triggers: ["/migrate"]
---

# Migrate — Django 마이그레이션 절차

## 목적

모델 변경 시 마이그레이션을 안전하게 생성하고 적용합니다.

## 실행 절차

### 1단계: 변경 사항 확인
```bash
git diff -- "*/models.py"
```

### 2단계: 마이그레이션 생성
```bash
python manage.py makemigrations [앱이름]
```

생성된 파일을 반드시 읽고 의도한 변경과 일치하는지 확인.

### 3단계: SQL 미리보기 (중요 변경 시)
```bash
python manage.py sqlmigrate [앱이름] [마이그레이션번호]
```

### 4단계: 적용
```bash
# 로컬
python manage.py migrate

# 특정 앱만
python manage.py migrate [앱이름]
```

### 5단계: 검증
```bash
python manage.py showmigrations
pytest  # 관련 테스트 통과 확인
```

## 주의 사항

- `null=False` 필드 추가 시 기본값 필수
- 대용량 테이블 컬럼 추가는 `db_default` 또는 별도 배포 전략 필요
- 마이그레이션 파일은 반드시 git에 포함
