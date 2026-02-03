class Instruction {
  final int step;
  final String text;
  final int? timeMinutes;

  Instruction({
    required this.step,
    required this.text,
    this.timeMinutes,
  });

  Map<String, dynamic> toJson() => {
        'step': step,
        'text': text,
        if (timeMinutes != null) 'timeMinutes': timeMinutes,
      };

  factory Instruction.fromJson(Map<String, dynamic> json) => Instruction(
        step: (json['step'] as num?)?.toInt() ?? 1,
        text: json['text'] as String? ?? json['instruction'] as String? ?? '',
        timeMinutes: (json['timeMinutes'] as num?)?.toInt(),
      );
}
