## BUG-2748 · VTT/SRT 仅含空白的分隔行让整份字幕解析为 0 条 cue（副字幕加载 .vtt 失败）
- **报告**：2026-09-28（用户：「想挂副字幕，好像不支持 .vtt？支持 vtt 格式字幕吗，不支持补一下各种字幕支持」）
- **真实性**：✅ 真 bug。选择器 / 格式路由 / sidecar 扫描都认 `.vtt`（`subtitleFormatForPath` 早有 vtt 分支），坏在解析器的数据模型：`packages/fushi_audio/lib/src/parsers/vtt_parser.dart` 与 `srt_parser.dart` 旧实现先 `split(RegExp(r'\n{2,}'))` 切 block、**切完才 trim 行**。
  - 分隔行只要带一个空格 / Tab（转换器、编辑器常见），`\n \n` 不算空行 → 整份文件并成一个 block；VTT 下它以 `WEBVTT` 开头，被当头部整块跳过 → **0 条 cue** → 「字幕加载失败」（实测探针：`WEBVTT\n \n00:00:01.000 --> …` → `[]`）。SRT 下只剩第一条，后续 cue 的序号与时间码被拼进正文。
  - 同一模型的连带缺陷：头部与首条 cue 缺空行时首条丢失；SRT 要求 block ≥3 行，无序号单行 cue 被丢；SRT 结束时间后带坐标（`X1:…`）整条丢；无毫秒时间码被拒；`&amp;` `&lt;` `&nbsp;` 等实体原样显示。
  - 另：外挂字幕扩展名白名单在十几处各写一份 `{srt,vtt,ass,ssa}`，SAMI（.smi，韩文字幕主流）/ TTML·DFXP（流媒体下载）/ SBV（YouTube）完全不支持。
- **[x] ① 已修复** — 根因修复：`cue_timeline_scanner.dart` 逐行状态机取代 block 模型（时间行开 cue、空白行收 cue、cue 外其它行一律忽略——头部 / NOTE / STYLE / 序号行的特判随之消失），SRT/VTT 共用它与共用收尾段 `buildTimedTextCues`；`stripHtmlTags` 剥标签后解码实体。新增 `SamiParser` / `TtmlParser` / `SbvParser`。`video_subtitle_source.dart` 的 `kSubtitleFormatByExtension` 成为外挂字幕扩展名唯一真相源，选择器 / 来源库扫描 / sidecar 扫描与互联上传白名单 / 下载与在线源落盘保留扩展名全部从它派生。
- **[x] ② 已加自动化测试** — `fushi/test/media/video/subtitle_format_support_test.dart`（空白分隔行、头部粘连、NOTE/STYLE/REGION、实体、宽松时间码、SRT 无序号与坐标、SAMI 多语言/清屏、TTML clock/tick/dur/帧、SBV、路由表 = 白名单、sidecar 优先级不变与穿越拒绝）。
- **备注**：MicroDVD `.sub` 未支持（帧号计时需要帧率、且与 VobSub 位图 `.sub` 同扩展名）；下载管线对 `.sub` 维持原样保留扩展名的既有行为。有声书 / 书导入的字幕集合（含 lrc）是另一域，未改。
