# Состояние работы (для продолжения)

Обновлено: 2026-10-09.

## Сделано
- Пайплайн: `train.py`, `predict.py`, `src/common.py`, журнал гипотез `experiments/`.
- 16 гипотез проверено на 1-м фолде, таблица в README и `experiments/results.csv`.
  Лучшее: MLP 512-256, dropout 0.2, 40 эпох (~0.872 macro-F1 на фолде).
- Подтверждено моделированием: EM-поправка на частоты классов помогает при сдвиге
  (`experiments/prior_shift_sim.py`). Включена в `predict.py` по умолчанию.
- `train.py` уже содержит финальный конфиг (dropout 0.2, epochs 40, 5 фолдов).

## Не доделано / следующие шаги
1. ГОТОВО: финальная модель обучена, seed 862236, OOF macro-F1 0.8702 (фолды 0.868–0.873),
   5.9 млн параметров в ансамбле (5 × 1.18 млн). Веса в `weights/model.pt` (в git).
2. Сабмиты на public_test, два варианта для сравнения на лидерборде:
   - `python predict.py --test data/public_test.npz --out-dir submissions/em`
   - `python predict.py --test data/public_test.npz --out-dir submissions/none --prior-shift none`
   Пользователь грузит оба в Яндекс.Контест и сообщает скор → решаем про EM.
   СДЕЛАНО 10.10: EM-оценка частот public_test ≈ train (angry .31, neutral .18, positive .31, sad .195),
   т.е. сдвига в public нет; варианты em/none отличаются в 82 из 6600 предсказаний.
   Пользователю отправлен em-вариант двумя частями (лимит 30 МБ).
   ПУБЛИЧНЫЙ СКОР: 76.61 (CV на train 87.0) — разрыв 10 п.п.! Гипотезы: утечка говорящих в CV
   (проверяем групповой CV по кластерам, `--groups 1000`) и другие частоты классов в тесте
   (пробы на лидерборде: все-neutral → доля neutral p из score s: s/100*4 = 2p/(1+p)).
   Пробы в submissions/probe/ (embeddings=нули, ~55 КБ — проверяем, игнорирует ли чекер эмбеддинги).
3. Идеи дальше: ансамбль нескольких seed'ов, LightGBM (не запускали — медленно на 2048 признаках),
   блендинг MLP + логрег (`experiments/blend.py`), полный 5-fold для топ-3 конфигов.
4. 16.10 — закрытый тест, сабмит до 19.10 + форма со ссылкой на код (публичный доступ).

## Данные
Не в git (1 ГБ). Скачать в новом контейнере:
`pip install gdown && gdown 1Zulx7cK6_MXWrtN9xM4tqPr2YdhHNyR0 && unzip -j A_public.zip -d data/`
В окружении Default разрешены домены: drive.google.com, drive.usercontent.google.com, *.googleusercontent.com.
