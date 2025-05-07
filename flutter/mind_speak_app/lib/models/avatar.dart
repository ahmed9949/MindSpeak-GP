class AvatarModel {
  final String name;
  final String imagePath;
  final String modelPath;

  // Animation names using the exact format from your logs
  final String idleAnimation;
  final String talkingAnimation;
  final String thinkingAnimation;
  final String clappingAnimation;
  final String greetingAnimation;

  const AvatarModel({
    required this.name,
    required this.imagePath,
    required this.modelPath,
    this.idleAnimation = 'idle', // Match exact casing from logs
    this.talkingAnimation = 'talking', // Match exact casing from logs
    this.thinkingAnimation = 'thinking',
    this.clappingAnimation = 'clapping',
    this.greetingAnimation = 'greeting',
  });
}
