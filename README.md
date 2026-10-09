# Голос клиента (MTS / MWS): классификация эмоций по аудио-эмбеддингам

Классы: `angry`, `neutral`, `positive`, `sad`. Метрика: macro-F1.

## Структура

| Файл | Что делает |
|---|---|
| `train.py` | обучает финальную модель (ансамбль 5 MLP по фолдам + множители классов под macro-F1), пишет `weights/model.pt` |
| `predict.py` | загружает веса, без обучения пишет `submission_seed_{SEED}.npz` (`embeddings`, `targets`) |
| `src/common.py` | загрузка данных, нормализация, MLP, фиксация seed, подбор множителей классов |
| `experiments/run_experiments.py` | журнал гипотез: одинаковый 5-fold CV для каждой, результаты в `experiments/results.csv` |
| `experiments/blend.py` | проверка ансамблей из разных моделей по OOF-вероятностям |

## Запуск

```bash
pip install -r requirements.txt
# положить train.npz и public_test.npz в data/
python experiments/run_experiments.py --data-dir data   # (опционально) все гипотезы
python train.py --data-dir data                          # seed выбирается случайно и печатается
python predict.py --test data/public_test.npz            # -> submission_seed_{SEED}.npz
```

Воспроизведение: `python train.py --seed <SEED>`. Seed хранится в весах и в имени файла сабмита.

## Решение

1. **Предобработка.** Стандартизация признаков по статистикам train (опционально L2-нормализация).
2. **Модель.** MLP `d → 512 → 256 → 4` (BatchNorm, GELU, Dropout), AdamW + OneCycle,
   label smoothing, веса классов `sqrt(1/частота)` против дисбаланса.
3. **Валидация.** Stratified 5-fold; в каждом фолде лучшая эпоха выбирается по macro-F1.
   На тесте вероятности 5 фолдовых моделей усредняются.
4. **Подгонка под macro-F1.** Обучение идёт по cross-entropy, а оценка по macro-F1, поэтому
   на OOF-вероятностях координатным спуском подбираются множители классов: прогноз
   `argmax(p · s)`. Эффект оценивается честно: множители подбираются на одних фолдах OOF,
   а оцениваются на других (`cv_f1_tuned` в журнале).

## Проверенные гипотезы

См. `experiments/results.csv` (заполняется после запуска на реальных данных):
линейная модель с весами классов и без, LightGBM, MLP без весов и с весами `sqrt`/`1/freq`,
L2-нормализация, размер сети (1 слой 256 / 512-256 / 1024-512), mixup, сила dropout,
подбор порогов, блендинг MLP + LightGBM + логрег.
