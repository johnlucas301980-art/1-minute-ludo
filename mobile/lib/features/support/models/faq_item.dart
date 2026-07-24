/// A single frequently-asked-question returned by the support FAQ endpoint.
class FaqItem {
  const FaqItem({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
  });

  final String id;
  final String category;
  final String question;
  final String answer;

  factory FaqItem.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final category = json['category'];
    final question = json['question'];
    final answer = json['answer'];

    if (id is! String ||
        category is! String ||
        question is! String ||
        answer is! String) {
      throw const FormatException('Invalid FAQ payload.');
    }

    return FaqItem(
      id: id,
      category: category,
      question: question,
      answer: answer,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FaqItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          category == other.category &&
          question == other.question &&
          answer == other.answer;

  @override
  int get hashCode => Object.hash(id, category, question, answer);

  @override
  String toString() => 'FaqItem(id: $id, category: $category, question: $question)';
}
