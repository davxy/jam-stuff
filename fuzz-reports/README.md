## Disputed Reports (0.6.7)

|            | boka | jamduna | jamixir | jamzig | jamzilla | javajam | spacejam | vinwolf |
|------------|------|---------|---------|--------|----------|---------|----------|---------|
| 1754982630 |      |         |         |        |          |         |          |         |
| 1754983524 |  ❌  |         |         |        |          |         |          |         |
| 1754984893 |      |         |         |        |          |         |          |         |
| 1754988078 |      |         |   ❌    |        |          |         |          |         |
| 1754990132 |  ❌  |         |         |        |          |         |          |         |
| 1755081941 |  ❌  |         |         |        |          |         |          |         |
| 1755082451 |  ❌  |         |         |        |          |         |          |         |
| 1755083543 |      |         |         |        |          |         |          |         |
| 1755150174 |      |         |         |        |          |         |          |         |
| 1755151480 |      |         |         |        |          |         |          |         |
| 1755155137 |      |         |         |        |          |         |          |         |
| 1755183715 |  ❌  |         |         |        |          |         |          |         |
| 1755185281 |  ❌  |         |         |        |          |         |          |         |
| 1755186567 |  ❌  |         |         |        |          |         |          |         |
| 1755186771 |      |         |         |        |          |         |          |         |
| 1755248769 |  ❌  |         |         |        |          |         |          |         |
| 1755248982 |      |         |   ❌    |        |          |         |          |         |
| 1755250287 |  ❌  |         |         |        |          |         |          |         |
| 1755251719 |      |         |   ❌    |        |          |         |          |         |
| 1755252727 |      |         |         |        |          |         |          |         |
| 1755530300 |      |         |   ❌    |        |          |         |          |         |
| 1755530397 |      |         |         |        |          |         |          |         |
| 1755530466 |      |         |         |        |          |         |          |         |
| 1755530509 |      |         |   ❌    |        |          |         |          |         |
| 1755531265 |      |         |   ❌    |        |          |         |          |         |
| 1755530535 |      |         |   ❌    |        |          |         |          |         |
| 1755530728 |      |         |   ❌    |        |          |         |          |         |
| 1755530896 |      |         |   ❌    |        |          |         |          |         |
| 1755620371 |      |         |   ❌    |        |          |         |          |         |

* ❌ := Fails with report
* 💀 := Crash or fuzzer protocol failure

Empty cells indicate successful processing without disputes.
Only disputed reports are shown in the table

### Reports Organization

- Reports are stored **per team** in the `./<jam-version>/reports` subfolder.  
- Traces are stored in the `./<jam-version>/traces` subfolder.  
- Each report is named after the **trace involved**.
- **Disputed traces** are preserved permanently, even after the dispute has been resolved for all teams.  
