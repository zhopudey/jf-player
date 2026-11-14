/// Maps a server-reported subtitle codec to a canonical token used for BOTH the
/// offline subtitle file extension and the codec passed to the player backend.
///
/// Keeping a single mapping shared by the download and offline-playback paths
/// guarantees the file written at download time and the file looked up at
/// playback time agree. The token also feeds the media3 backend, which needs it
/// to pick a MIME type for sideloaded subtitles (mpv autodetects, but a correct
/// extension is still preferable).
/// Whether the server can serve this subtitle codec as text.
///
/// Bitmap formats (PGS, VobSub, DVB) carry no text: asking the server for a
/// `.srt` of one makes it try to OCR the stream, and that request does not
/// return (measured against the live server — timed out at 60 s).
bool isTextSubtitleCodec(String? codec) {
  switch ((codec ?? '').trim().toLowerCase()) {
    case 'subrip':
    case 'srt':
    case 'ass':
    case 'ssa':
    case 'vtt':
    case 'webvtt':
    case 'ttml':
    case 'dfxp':
    case 'mov_text':
    case 'text':
    case 'smi':
    case 'sami':
    case 'subviewer':
    case 'microdvd':
      return true;
    default:
      return false;
  }
}

String canonicalSubtitleCodec(String? codec) {
  switch ((codec ?? '').trim().toLowerCase()) {
    case 'ass':
    case 'ssa':
      return 'ass';
    case 'vtt':
    case 'webvtt':
      return 'vtt';
    case 'ttml':
      return 'ttml';
    case 'subrip':
    case 'srt':
    case 'mov_text':
    default:
      return 'srt';
  }
}
