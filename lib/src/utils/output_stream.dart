/// A simple way to abstract writing output to a

sealed class OutputStream {}

class ConsoleOutputStream extends OutputStream {}

class FileOutputStream extends OutputStream {}

class TextOutputStream extends OutputStream {}
