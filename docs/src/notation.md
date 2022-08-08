# [Notation](@id notation)

This is the notation used throughout the package, including in the docstrings of functions, and where possible used in the code itself.
It should very closely match the notation used in Invenia's formulations of
MISO day-ahead market clearing ([PDF](https://drive.google.com/file/d/1ruSRtcLl9oicaJtZqWPI8S28sHW2C8Ji/view), [Overleaf](https://www.overleaf.com/project/5f2453fd81a39d000135af50)) and
MISO real-time market clearing ([PDF](https://drive.google.com/file/d/1IhAv-Djqc72RPXsB3JBzWYYYbcpw8_0q/view), [Overleaf](https://www.overleaf.com/project/609119ba802ae360964406ba)).

## Sets

|**Notation** | **Description**|
| :------------ | :-----------|
|$\mathcal{B}$ | Set of nodes representing the immediate neighbours of the ISO. |
|$\mathcal{C}$ | Set of contingency scenarios considered. |
|$\mathcal{D}$ | Set of virtual demands. |
|$\mathcal{D}_n$ | Set of virtual demands at node $n$. |
|$\mathcal{F}$ | Set of fixed demands. |
|$\mathcal{F}_n$ | Set of fixed demands at node $n$. |
|$\mathcal{G}$ | Set of generators excluding demand response resources type-I. |
|$\mathcal{G}^0_{off}$ | Set of generators which are not initially committed. |
|$\mathcal{G}^0_{on}$ | Set of generators which are initially committed. |
|$\mathcal{G}_n$ | Set of generators excluding demand response resources type-I at node $n$. |
|$\mathcal{G}_z$ | Set of generators in ISO zone $z$ for reserve procurement. |
|$\mathcal{G}_{av,t}$ | Set of generators with enabled availability flag at time $t$. |
|$\mathcal{G}_{mr,t}$ | Set of generators with enabled must-run flag at time $t$. |
|$\mathcal{I}$ | Set of virtual supplies. |
|$\mathcal{I}_n$ | Set of virtual supplies at node $n$. |
|$\mathcal{L}_c$ | Set of lines/transformers on outage in the contingency scenario $c$. |
|$\mathcal{M}_0$ | Set of monitored lines/transformers in the base-case. |
|$\mathcal{M}_c$ | Set of monitored lines/transformers in the contingency scenario $c$. |
|$\mathcal{N}_m$ | Set of nodes with non-zero injection shift factor for line/transformer $m$. |
|$\mathcal{Q}_{d,t}$ | Set of bid curve blocks of virtual demand $d$ at time $t$. |
|$\mathcal{Q}_{g,t}$ | Set of offer curve blocks of generator $g$ at time $t$. |
|$\mathcal{Q}_{g,t}$ | Set of offer curve blocks of generator $g$ at time $t$. |
|$\mathcal{Q}_{i,t}$ | Set of offer curve blocks of virtual supply $i$ at time $t$. |
|$\mathcal{Q}_{s,t}$ | Set of bid curve blocks of price-sensitive load bid $s$ at time $t$. |
|$\mathcal{S}$ | Set of price-sensitive loads. |
|$\mathcal{S}_n$ | Set of price-sensitive loads at node $n$. |
|$\mathcal{T}$ | Set of time epochs. |
|$\mathcal{V}$ | Set of electric grid buses including the immediate ISO neighbours. |
|$\mathcal{Z}$ | Set of defined reserve zones in the ISO. |


## Parameters

|**Notation** | **Description**|
| :------------ | :-----------|
|$C^{nl}_{g,t}$ | No-load cost of generator $g$ at time $t$ in $\text{hour}$. |
|$C^{off-sup}_{g,t}$ | Offline supplemental reserve cost of generator $g$ at time $t$ in $\text{MW}$. |
|$C^{on-sup}_{g,t}$ | Online supplemental reserve cost of generator $g$ at time $t$ in $\text{MW}$. |
|$C^{reg}_{g,t}$ | Regulation reserve cost of generator $g$ at time $t$ in $\text{MW}$. |
|$C^{spin}_{g,t}$ | Spinning reserve cost of generator $g$ at time $t$ in $\text{MW}$. |
|$C^{st}_{g,t}$ | Start-up cost of generator $g$ at time $t$ in \$. |
|$DT^0_{g}$ | Number of time periods the unit has been off prior to the first time period of generator $g$ in hours. |
|$DT_{g}$ | Minimum down-time of generator $g$ in hours. |
|$D_{f,t}$ | Fixed demand $f$ at time $t$ in $\text{MW}$. |
|$\overline{D}_{d,t,q}$ | Maximum volume of virtual demand $d$ at time $t$ for block $q$ in $\text{MW}$. |
|$\overline{D}_{s,t,q}$ | Maximum volume of price-sensitive load $s$ at time $t$ for block $q$ in $\text{MW}$. |
|$FL^{rate-a}_m$ | Rate-A power flow limit on line/transformer $m$ in $\text{MW}$. |
|$FL^{rate-b}_m$ | Rate-B power flow limit on line/transformer $m$ in $\text{MW}$. |
|$NI_{n,t}$ | Net interchange at node $n$ at time $t$ in $\text{MW}$. |
|$P^0_{g}$ | Initial output power of generator $g$ in $\text{MW}$ ($P^0_{g} \neq 0 ~\forall g \in \mathcal{G}^0_{on}, P^0_{g} = 0~\forall g \in \mathcal{G}^0_{off}$). |
|$P^{max}_{g,t}$ | Economic maximum energy dispatch of generator $g$ at time $t$ in $\text{MW}$. |
|$P^{min}_{g,t}$ | Economic minimum energy dispatch of generator $g$ at time $t$ in $\text{MW}$. |
|$P^{reg-max}_{g,t}$ | Maximum energy dispatch of generator $g$ at time $t$ when committed to provide regulation in $\text{MW}$. |
|$P^{reg-min}_{g,t}$ | Minimum energy dispatch of generator $g$ at time $t$ when committed to provide regulation in $\text{MW}$. |
|$\overline{P}_{g,t,q}$ | Maximum energy dispatch of generator $g$ at time $t$ for block $q$ in $\text{MW}$. |
|$\overline{P}_{i,t,q}$ | Maximum volume of virtual supply $i$ at time $t$ for block $q$ in $\text{MW}$. |
|$RR_{g}$ | Ramp-rate of generator $g$ in $\text{MW}/\text{minute}$. |
|$R^{OR-req}_{Tot,t}$ | Market-wide operating reserve requirement at time $t$ in $\text{MW}$. |
|$R^{OR-req}_{z,t}$ | Zone $z$ operating reserve requirement at time $t$ in $\text{MW}$. |
|$R^{RS-req}_{Tot,t}$ | Market-wide regulation+spin reserve requirement at time $t$ in $\text{MW}$. |
|$R^{RS-req}_{z,t}$ | Zone $z$ regulation+spin reserve requirement at time $t$ in $\text{MW}$. |
|$R^{reg-req}_{Tot,t}$ | Market-wide regulation reserve requirement at time $t$ in $\text{MW}$. |
|$R^{reg-req}_{z,t}$ | Zone $z$ regulation reserve requirement at time $t$ in $\text{MW}$. |
|$SD_{g}$ | Shut-down capability of generator $g$ in $\text{MW}$. |
|$SI_{n,t}$ | Scheduled net interchange at node $n$ at time $t$ in $\text{MW}$. |
|$SU_{g}$ | Start-up capability of generator $g$ in $\text{MW}$. |
|$T$ | Number of intervals (hours) in the market solve horizon. |
|$UT^0_{g}$ | Number of time periods the unit has been on prior to the first time period of generator $g$ in hours. |
|$UT_{g}$ | Minimum up-time of generator $g$ in hours. |
|$U^0_{g}$ | Initial commitment status of generator $g$ ($U^0_{g} = 1~\forall g \in \mathcal{G}^0_{on}, U^0_{g} = 0~\forall g \in \mathcal{G}^0_{off}$). |
|$U^{reg}_{g,t}$ | Regulation Reserve commitment status of generator $g$ at time $t$. |
|$U_{g,t}$ | Commitment status of generator $g$ at time $t$. |
|$\Delta t$ | Time difference between two consecutive simulation intervals in minutes. |
|$\Gamma^{OR-req}_{Tot,t}$ | Market-wide operating reserve requirement slack variable penalty cost at time $t$ in $\text{MW}$. |
|$\Gamma^{OR-req}_{z,t}$ | Zone $z$ operating reserve requirement slack variable penalty cost at time $t$ in $\text{MW}$. |
|$\Gamma^{RS}_{Tot,t}$ | Market-wide regulation+spin reserve slack variable penalty cost at time $t$ in $\text{MW}$. |
|$\Gamma^{RS}_{z,t}$ | Zone $z$ regulation+spin reserve slack variable penalty cost at time $t$ in $\text{MW}$. |
|$\Gamma^{flow,0}_{1,m}$ | Line/transformer $m$ power flow step-1 slack variable penalty cost in the base-case in $\text{MW}$. |
|$\Gamma^{flow,0}_{2,m}$ | Line/transformer $m$ power flow step-2 slack variable penalty cost in the base-case in $\text{MW}$. |
|$\Gamma^{flow,c}_{1,m}$ | Line/transformer $m$ power flow step-1 slack variable penalty cost in the contingency scenario $c$ in $\text{MW}$. |
|$\Gamma^{flow,c}_{2,m}$ | Line/transformer $m$ power flow step-2 slack variable penalty cost in the contingency scenario $c$ in $\text{MW}$. |
|$\Gamma^{reg-req}_{Tot,t}$ | Market-wide regulation requirement slack variable penalty cost at time $t$ in $\text{MW}$. |
|$\Gamma^{reg-req}_{z,t}$ | Zone $z$ regulation requirement slack variable penalty cost at time $t$ in $\text{MW}$. |
|$\Lambda^{bid}_{d,t,q}$ | Bid price of virtual demand $d$ at time $t$ for block $q$ in $\text{MW}$. |
|$\Lambda^{bid}_{s,t,q}$ | Bid price of price-sensitive load $s$ at time $t$ for block $q$ in $\text{MW}$. |
|$\Lambda^{offer}_{g,t,q}$ | Offer price of generator $g$ at time $t$ for block $q$ in $\text{MW}$. |
|$\Lambda^{offer}_{i,t,q}$ | Offer price of virtual supply $i$ at time $t$ for block $q$ in $\text{MW}$. |
|$\text{ISF}_{m,n}$ | Injection shift factor on line/transformer $m$ for injection at bus $n$. |
|$\text{LODF}^c_{m,l}$ | Line outage distribution factor on line/transformer $m$ in the contingency scenario $c$ for line/transformer $l$ on outage. |


## Variables

|**Notation** | **Description**|
| :------------ | :-----------|
|$c_{d,t}(.)$ | Variable cost function of virtual demand $d$ at time $t$ in \$. |
|$c_{g,t}(.)$ | Variable cost function of generator $g$ at time $t$ in \$. |
|$c_{i,t}(.)$ | Variable cost function of virtual supply $i$ at time $t$ in \$. |
|$c_{s,t}(.)$ | Variable cost function of price-sensitive load $s$ at time $t$ in \$. |
|$d_{d,t,q}$ | Cleared MW of virtual demand $d$ at time $t$ for block $q$ in $\text{MW}$. |
|$d_{d,t}$ | Cleared MW of virtual demand $d$ at time $t$ in $\text{MW}$. |
|$d_{s,t,q}$ | Cleared MW of price-sensitive load $s$ at time $t$ for block $q$ in $\text{MW}$. |
|$d_{s,t}$ | Cleared MW of price-sensitive load $s$ at time $t$ in $\text{MW}$. |
|$fl^{0}_{m,t}$ | Power flow on line/transformer $m$ at time $t$ in the base-case in $\text{MW}$. |
|$fl^{c}_{m,t}$ | Power flow on line/transformer $m$ at time $t$ in the contingency scenario $c$ in $\text{MW}$. |
|$p^{net}_{n,t}$ | Net power injection at node $n$ at time $t$ in $\text{MW}$. |
|$p_{g,t,q}$ | Energy dispatch of generator $g$ at time $t$ for block $q$ in $\text{MW}$. |
|$p_{g,t}$ | Energy dispatch of generator $g$ at time $t$ in $\text{MW}$. |
|$p_{i,t,q}$ | Cleared MW of virtual supply $i$ at time $t$ for block $q$ in $\text{MW}$. |
|$p_{i,t}$ | Cleared MW of virtual supply $i$ at time $t$ in $\text{MW}$. |
|$r^{cont}_{g,t}$ | contingency reserve of generator $g$ at time $t$ in $\text{MW}$. |
|$r^{off-sup}_{g,t}$ | Offline supplemental reserve of generator $g$ at time $t$ in $\text{MW}$. |
|$r^{off-sup}_{g,t}$ | Offline supplemental reserve of generator $g$ at time $t$ in $\text{MW}$. |
|$r^{on-sup}_{g,t}$ | Online supplemental reserve of generator $g$ at time $t$ in $\text{MW}$. |
|$r^{reg}_{g,t}$ | Regulation reserve of generator $g$ at time $t$ in $\text{MW}$. |
|$r^{spin}_{g,t}$ | Spinning reserve of generator $g$ at time $t$ in $\text{MW}$. |
|$sl1^{flow,0}_{m,t}$ | Step-1 slack variable for power flow on line/transformer $m$ at time $t$ in the base-case in $\text{MW}$. |
|$sl1^{flow,c}_{m,t}$ | Step-1 slack variable for power flow on line/transformer $m$ at time $t$ in the contingency scenario $c$ in $\text{MW}$. |
|$sl2^{flow,0}_{m,t}$ | Step-2 slack variable for power flow on line/transformer $m$ at time $t$ in the base-case in $\text{MW}$. |
|$sl2^{flow,c}_{m,t}$ | Step-2 slack variable for power flow on line/transformer $m$ at time $t$ in the contingency scenario $c$ in $\text{MW}$. |
|$sl^{OR-req}_{Tot,t}$ | Slack variable for market-wide operating reserve requirement at time $t$ in $\text{MW}$. |
|$sl^{OR-req}_{z,t}$ | Slack variable for zone $z$ operating reserve requirement at time $t$ in $\text{MW}$. |
|$sl^{RS}_{Tot,t}$ | Slack variable for market-wide regulation+spin reserve requirement at time $t$ in $\text{MW}$. |
|$sl^{RS}_{z,t}$ | Slack variable for zone $z$ regulation+spin reserve requirement at time $t$ in $\text{MW}$. |
|$sl^{reg-req}_{Tot,t}$ | Slack variable for market-wide regulation reserve requirement at time $t$ in $\text{MW}$. |
|$sl^{reg-req}_{z,t}$ | Slack variable for zone $z$ regulation reserve requirement at time $t$ in $\text{MW}$. |
|$u^{reg}_{g, t}$ | Regulation commitment status of generator $g$ at time $t$. |
|$u_{g, t}$ | Commitment status of generator $g$ at time $t$. |
|$v_{g, t}$ | Start-up status of generator $g$ at time $t$. |
|$w_{g, t}$ | Shut-down status of generator $g$ at time $t$. |
