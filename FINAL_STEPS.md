# Закрытый тест 16–19 октября: пошаговая инструкция

Все четыре `predict.py` проверены «всухую» на копиях тестов с другими именами (10.10.2026):
результат совпадает с лучшими сабмитами публичного лидерборда до последнего знака.

| Задача | Публичный LB | seed | Команда |
|---|---|---|---|
| A | 77.49 | 862236 | `python predict.py --test <private>.npz --out-dir out_A` |
| B | 96.70 | 654255 | `python task_b/predict.py --test <private>.csv --out-dir out_B` |
| C | 99.01 | 185065 | `python task_c/predict.py --test-dir <папка с .wav> --out-dir out_C` |
| D | 77.25 | 352773 | `python task_d/predict.py --test <private>.csv --out-dir out_D` |

Обучать заново **не нужно**: веса лежат в репозитории (`weights/`, `task_b/weights/`, `task_c/weights/`,
`task_d/weights/`). Каждый `predict.py` пишет `submission_seed_{SEED}.{npz|csv}` — имя уже в нужном формате.

## Шаг 1. Скачать закрытые тесты (16.10)
1. Зайти в контест (Лига Профессионалов: https://official.contest.yandex.ru/contest/98292/enter),
   скопировать ссылки на закрытые наборы по задачам A, B, C, D и прислать их Claude в чат.
2. Если ссылки не на Google Drive, а, например, на Яндекс.Диск — заранее добавить домены в настройки окружения
   («Изменить облачную среду» → «Разрешённые домены»): `disk.yandex.ru`, `*.disk.yandex.ru`, `*.yandex.net`.
   Уже разрешены: `drive.google.com`, `drive.usercontent.google.com`, `*.googleusercontent.com`,
   `huggingface.co`, `*.huggingface.co`, `*.hf.co`.

## Шаг 2. Если контейнер пересоздан — вернуть данные train (нужны для B/D-предикта и C-признаков)
```bash
pip install -r requirements.txt gdown statsmodels
gdown 1Zulx7cK6_MXWrtN9xM4tqPr2YdhHNyR0 && unzip -j A_public.zip -d data/            # A
gdown 1EpLYYyaTOGmD3mq5ECtyLSrcgB6niDNt && unzip -j B_sber_public.zip -d task_b/data/ # B
gdown --folder 1RXBJiYEHBT3U9gOuzhguT5y8ytOjHrEx   # C: train.zip + public_test.zip -> task_c/data/
gdown --folder 1eVLV_QfeeTwsAq0B1mfCTXKFLf78vsvx   # D: D_sber.zip -> task_d/data/
```
Для predict нужны: A — ничего, кроме весов; B — ничего; C — ничего (признаки считаются из аудио);
D — `task_d/data/hard_train.csv` (только список категорий).

## Шаг 3. Предсказания (≈10 минут на всё; C — дольше всех, считает признаки из аудио)
Команды из таблицы выше. Проверить, что число строк совпадает с размером закрытого теста
(A, B, D — 6600 / 1000 / 2000; C — 2712 по условию).

## Шаг 4. Загрузить в контест
- B, C, D — маленькие CSV, грузятся как есть.
- A — `.npz` около 52 МБ (внутри обязательно полные эмбеддинги — с нулями чекер даёт PE).
  В чат файл > 30 МБ не передаётся, поэтому Claude режет его на 2 части; склейка в PowerShell:
  ```
  cmd /c copy /b submission_seed_862236.npz.part0 + submission_seed_862236.npz.part1 submission_seed_862236.npz
  (Get-Item submission_seed_862236.npz).Length
  ```

## Шаг 5. Код для жюри (до 19.10 включительно)
1. Собрать архив репозитория (код + веса + `requirements.txt` + README по задачам) — Claude соберёт `solution.zip`.
2. Загрузить на Яндекс.Диск или Google Drive, открыть доступ «всем, у кого есть ссылка».
3. **Проверить ссылку в режиме инкогнито.**
4. Отправить ссылку через форму каждой задачи:
   - A: ссылка на решение — https://forms.yandex.ru/u/6a887aad9029024c31c9d954 ,
        и обязательно заполнить — https://forms.yandex.ru/u/6a8b1453e010db8926c82e95/
   - C: https://forms.yandex.ru/u/6a9679b1e010db034586dc37
   - D: https://forms.yandex.ru/u/6a95100702848fc99a1df08f
   - B: ссылка на форму — в условии задачи B в контесте (в скопированном тексте её не было).

## Важно
- Итоговый рейтинг считается по закрытому набору,
  поэтому отправляем ровно те модели, что в таблице (их и проверит жюри).
- Не использовать закрытый тест для обучения или подбора (запрещено условиями C и D).
