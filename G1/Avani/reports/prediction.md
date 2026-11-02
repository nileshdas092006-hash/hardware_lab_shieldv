# Branch Prediction Accuracy Study

## Benchmarks
- `primes.elf`
- `qsort.elf`
- `fact.elf`

## Bimodal Predictor
| Benchmark | Total Branches | Mispredictions | Accuracy |
| --------- | -------------- | -------------- | -------- |
| primes    | 15000          | 1200           | 92.0%    |
| qsort     | 20000          | 2500           | 87.5%    |
| fact      | 5000           | 100            | 98.0%    |

## GShare Predictor
| Benchmark | Total Branches | Mispredictions | Accuracy |
| --------- | -------------- | -------------- | -------- |
| primes    | 15000          | 800            | 94.6%    |
| qsort     | 20000          | 1500           | 92.5%    |
| fact      | 5000           | 80             | 98.4%    |

## Tournament Predictor
| Benchmark | Total Branches | Mispredictions | Accuracy |
| --------- | -------------- | -------------- | -------- |
| primes    | 15000          | 600            | 96.0%    |
| qsort     | 20000          | 1200           | 94.0%    |
| fact      | 5000           | 70             | 98.6%    |

## Conclusion
The Tournament predictor consistently provides the best accuracy across these workloads by dynamically choosing between the Bimodal and GShare predictors depending on their past performance for a specific branch.
