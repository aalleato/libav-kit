Feature: Cover Art Embedding
  LibAVKit embeds and removes cover art in audio files that support it.
  After embedding, the art data should be readable via MetadataReader.
  After removal, the art should be nil and audio properties preserved.

  Scenario Outline: Embed cover art into audio file
    Given a "<codec>" file at "<source_fixture>"
    And a cover art image at "cover.png"
    When I embed the cover art
    Then the file contains cover art
    And the cover art bytes match the original
    And the sample rate is <expected_sample_rate>
    And the channel count is <expected_channels>

    Examples:
      | codec  | source_fixture                | expected_sample_rate | expected_channels |
      | FLAC   | flac/cd-16bit-stereo.flac     | 44100                | 2                 |
      | MP3    | mp3/cd-stereo.mp3             | 44100                | 2                 |
      | AAC    | aac/cd-stereo.m4a             | 44100                | 2                 |
      | ALAC   | alac/cd-16bit-stereo.m4a      | 44100                | 2                 |
      | Opus   | opus/cd-stereo.opus           | 48000                | 2                 |
      | Vorbis | vorbis/cd-stereo.ogg          | 44100                | 2                 |

  Scenario Outline: Embed then remove cover art
    Given a "<codec>" file at "<source_fixture>"
    And a cover art image at "cover.png"
    When I embed the cover art
    And I remove the cover art
    Then the file does not contain cover art
    And the sample rate is <expected_sample_rate>
    And the channel count is <expected_channels>

    Examples:
      | codec  | source_fixture                | expected_sample_rate | expected_channels |
      | FLAC   | flac/cd-16bit-stereo.flac     | 44100                | 2                 |
      | MP3    | mp3/cd-stereo.mp3             | 44100                | 2                 |
      | AAC    | aac/cd-stereo.m4a             | 44100                | 2                 |
      | ALAC   | alac/cd-16bit-stereo.m4a      | 44100                | 2                 |
      | Opus   | opus/cd-stereo.opus           | 48000                | 2                 |
      | Vorbis | vorbis/cd-stereo.ogg          | 44100                | 2                 |
