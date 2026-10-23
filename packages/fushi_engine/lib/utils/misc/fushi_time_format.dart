/// Used for formatting time-related strings.
abstract class FushiTimeFormat {

  /// `yyyy-MM-dd` day key（零填充月/日，可字典序比较）。统计行 dateKey、备份
  /// 文件名/日期展示共用此一处实现。
  static String dayKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// 本地化无关的 `HH:mm`（时/分恒补零，24 小时制）。
  static String hourMinute(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  /// 本地化无关的 `yyyy-MM-dd HH:mm`（不引 intl，跨 17 语言一致）。
  static String dateHourMinute(DateTime time) =>
      '${dayKey(time)} ${hourMinute(time)}';

}
