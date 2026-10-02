# Log

## 2026-10-02

* **Decision**: Recorded EM's choices for OD-05: the committee Safes manage the swap instances, the live parameters are copied by pair class, and instances come from the standard factory, so recovered tokens go to the treasury. Corrected ADR 007 and the LIP, which said that anyone can place an order and that the Aragon Agent manages every instance. Closed OD-18 with evidence, and added OD-20 for the pricing configuration. Added the Stonks research note. Amended INV-002 and INV-014.
* **Decision**: Recorded EM's choice for OD-04: Lido Lend counts against the protocol cap for its first three months, then is uncapped as a Lido product. Updated ADR 009, ADR 011, the open decisions (OD-04 closed; OD-12 gains the start-date reading), the parameters and the LIP draft. The attested computation now switches the Lido Lend key on that date.
* **Decision**: Recorded EM's choice for OD-03, the literal base of the yield-bearing cap. Updated ADR 009, the open decisions, the parameters and the LIP draft. The attested computation ran again with the literal base; it gives the yield-bearing key no figure until the first retune after seeding.
* **Decision**: Recorded EM's choices for OD-02 (Safe v1.5.0 for both new Safes, on the condition that the screening vendor's guard is compatible) and OD-19 (operator Safe threshold 4 of 7). Added the research note on the compatibility check, which met the condition. OD-17 applies again.
* **Decision**: Recorded EM's choice for OD-01: the screening vendor's existing transaction guard on a dedicated operator Safe, which is also the trusted caller of every factory. Updated ADR 005, ADR 006 and ADR 010, the open decisions (OD-01 closed, OD-02 and OD-07 narrowed, OD-19 added), the parameters, INV-010, the runbook list, the LIP draft's section 9.1 and the harness README. The vendor's identity stays out; its evidence is cited as restricted.

## 2026-09-30

* **Initialization**: Created the bundle: the product brief, eleven decision records, the specification policy, the invariants, the LIP draft, the runbook index, four registers and two research notes. Every page is agent-drafted and carries `review_status: slop`.
* **Import**: Imported the LIP draft of 2026-09-22 from the design review. Removed the screening vendor's product description and the mandate size. Aligned the template catalogue, the LDO note and the test table with the decision log and the kit.
* **Evidence**: Re-ran the design's chain reads at block 26092572 and recorded each command.
