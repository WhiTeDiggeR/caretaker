# Комплекс v3 — обзорный граф маршрутов

Артефакт: `OVERVIEW-GRAPH-01`

Статус: `stage-1 / approved`

Граф показывает только крупные сектора, сети и межэтажные переходы. Точные двери, шлюзы и внутренние комнаты появятся в паспортах этапа 2. Закрытые грузовые гермошлюзы камер существуют физически, но не входят в проходимый граф.

```mermaid
flowchart TB
  subgraph U[LV-U · верхний]
    UEA[U-EMERGENCY] --- URA[U-ROUTE-A]
    UPAX((U-PAX)) --- UEA
    UPAX --- UDOM[U-DOMESTIC]
    UPAX --- UCTRL[U-CONTROL]
    UPAX --- UCORE[U-CENTRAL-CORE]
    UPAX --- UEAST[U-EAST-SUPPORT]
    UPAX --- UC4[U-CHAMBER-4]
    UPAX --- USEC[U-SECURITY]
    UPAX --- UC6[U-CHAMBER-6]
    USEC --- UFRT((U-FRT))
    UFRT --- UFR[U-FREIGHT]
  end

  subgraph L[LV-L · нижний]
    LPAX((L-PAX)) --- LOC[L-OLD-CORE]
    LOC --- LC1[L-CHAMBER-1]
    LOC --- LAR[L-ARCHIVE-A]
    LOC --- LOR[L-OLD-RECEIVING]
    LPAX --- LC2[L-CHAMBER-2]
    LPAX --- LSL[L-SLEEP-LAB]
    LPAX --- LC3[L-CHAMBER-3]
    LPAX --- LSI[L-SERVICE-INTERCHANGE]
    LPAX --- LCORE[L-CENTRAL-CORE]
    LPAX --- LEAST[L-EAST-STAIR]
    LPAX --- LC5[L-CHAMBER-5]
    LFRT((L-FRT)) --- LOR
    LFRT --- LSI
    LFRT --- LFS[L-FREIGHT-SERVICE]
  end

  subgraph T[LV-T · технический]
    TTECH((T-TECH)) --- TEN[T-ENERGY]
    TTECH --- TWORK[T-WORKSHOP]
    TTECH --- TOLD[T-OLD-ACCESS]
    TTECH --- TEAST[T-EAST-VERTICAL]
    TTECH --- TUTIL[T-UTILITIES]
    TTECH --- TCIRC[T-CIRCULATION]
    TCIRC --- TFRT((T-FRT))
    TFRT --- TFR[T-FREIGHT]
  end

  URA == A-ROUTE-A ==> LAR
  UCORE == A-MAIN-CORE ==> LCORE
  UEAST == A-EAST-STAIR ==> LEAST
  UFR == A-FREIGHT-LIFT ==> LFS
  LOR == R-OLD-FRT ==> UFRT
  LOC == A-OLD-STAIR ==> TOLD
  LSI == A-SERVICE-STAIR ==> TCIRC
  LEAST == A-EAST-STAIR ==> TEAST
  LFS == A-FREIGHT-LIFT ==> TFR
  LCORE -. A-MAIN-CORE · NO STOP .- TEAST
```

## Контролируемые связи сетей

- `U-PAX ↔ U-SECURITY ↔ U-FRT` — двухворотный КПП.
- `L-PAX ↔ L-SERVICE-INTERCHANGE ↔ L-FRT` — двойной шлюз.
- `T-TECH ↔ T-CIRCULATION ↔ T-FRT` — два физически разнесённых контролируемых перехода; на обзорном графе сведены в один узел сектора.

Прямые связи `U-PAX ↔ U-FRT`, `L-PAX ↔ L-FRT` и `T-TECH ↔ T-FRT` запрещены.
