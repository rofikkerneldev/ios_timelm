# Working on ios-timelm

- Target Device: **LG V60 ThinQ 5G (`timelm`, Qualcomm SM8250 / Snapdragon 865)**.
- Baseline Reference: `~/xnu/ios-sweet` (Snapdragon 732G SM7150 reference port).
- Hardware Specifications & Data Sources:
  - Mainline DTS: `~/alpha/kernel/lge/sm8250-mainline/arch/arm64/boot/dts/qcom/sm8250-lge-timelm.dts`
  - Base DTSI: `sm8250.dtsi`
  - Memory map: DDR RAM base at `0x80000000`, continuous upper bank `0xc0000000`-`0x17fffffff` (3 GiB), highmem `0x100000000` (up to 8 GiB).
  - Framebuffer: ABL splash region at `0x9c000000`, `1080x2460` (stride 4320, 32-bit ARGB/BGRA).
  - GICv3: GICD `0x17a00000`, GICR `0x17a60000`, Virtual Timer PPI 19 (`0x13`).
  - UFS: UFS 3.0 controller at `0x01d84000`, size `0x3000`.
- Maintain handoff and milestones in `NOTES.md`.
- Preserve calibration partitions (`modemst1`, `modemst2`, `fsg`, `fsc`, `persist`). Device boot experiments are done strictly via non-destructive `fastboot boot`.
