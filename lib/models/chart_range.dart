enum ChartRange {
  oneDay   ('1D', Duration(days: 1)),
  threeDays('3D', Duration(days: 3)),
  oneWeek  ('1S', Duration(days: 7)),
  oneMonth ('1M', Duration(days: 30)),
  threeMonths('3M', Duration(days: 90));

  const ChartRange(this.label, this.duration);
  final String label;
  final Duration duration;
}