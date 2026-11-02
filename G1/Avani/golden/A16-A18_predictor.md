# Golden Table for 2-bit Counters and GShare Indexing

## 2-Bit Saturating Counter State Machine
| Current State | Branch Taken | Next State | Prediction |
| ------------- | ------------ | ---------- | ---------- |
| 2'b00 (SNT)   | 0            | 2'b00      | Not Taken  |
| 2'b00 (SNT)   | 1            | 2'b01      | Not Taken  |
| 2'b01 (WNT)   | 0            | 2'b00      | Not Taken  |
| 2'b01 (WNT)   | 1            | 2'b10      | Taken      |
| 2'b10 (WT)    | 0            | 2'b01      | Taken      |
| 2'b10 (WT)    | 1            | 2'b11      | Taken      |
| 2'b11 (ST)    | 0            | 2'b10      | Taken      |
| 2'b11 (ST)    | 1            | 2'b11      | Taken      |

## GShare Indexing
Index = (PC [11:2]) XOR (Global History [9:0])
