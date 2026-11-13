resource "aws_medialive_input" "main" {
  name     = "${local.prefix}-input"
  type     = "MEDIACONNECT"
  role_arn = aws_iam_role.medialive.arn

  media_connect_flows {
    flow_arn = awscc_mediaconnect_flow.main.flow_arn
  }

  # wait on the propagation sleep above
  depends_on = [time_sleep.iam_propagation]
}

resource "aws_medialive_channel" "main" {
  name          = "${local.prefix}-ml"
  channel_class = "SINGLE_PIPELINE"
  role_arn      = aws_iam_role.medialive.arn
  log_level     = "WARNING"
  start_channel = false

  input_specification {
    codec            = "AVC"
    input_resolution = "HD"
    maximum_bitrate  = "MAX_20_MBPS"
  }

  input_attachments {
    input_attachment_name = "src"
    input_id              = aws_medialive_input.main.id

    input_settings {
      source_end_behavior = "CONTINUE"

      audio_selector {
        name = "default"
      }
    }
  }

  destinations {
    id = "mp2"
    settings {
      url = awscc_mediapackagev2_channel.main.ingest_endpoints[0].url
    }
  }

  encoder_settings {
    timecode_config {
      source = "SYSTEMCLOCK"
    }

    audio_descriptions {
      name                = "audio_aac"
      audio_selector_name = "default"

      codec_settings {
        aac_settings {
          bitrate           = 128000
          coding_mode       = "CODING_MODE_2_0"
          sample_rate       = 48000
          profile           = "LC"
          rate_control_mode = "CBR"
        }
      }
    }

    video_descriptions {
      name             = "video_1080"
      width            = 1920
      height           = 1080
      scaling_behavior = "DEFAULT"
      respond_to_afd   = "NONE"
      sharpness        = 50

      codec_settings {
        h264_settings {
          rate_control_mode     = "QVBR"
          qvbr_quality_level    = 8
          max_bitrate           = 5000000
          framerate_control     = "SPECIFIED"
          framerate_numerator   = 30
          framerate_denominator = 1
          gop_size              = 2
          gop_size_units        = "SECONDS"
          gop_closed_cadence    = 1
          gop_num_b_frames      = 2
          profile               = "HIGH"
          level                 = "H264_LEVEL_AUTO"
          scene_change_detect   = "ENABLED"
          par_control           = "INITIALIZE_FROM_SOURCE"
        }
      }
    }

    video_descriptions {
      name             = "video_720"
      width            = 1280
      height           = 720
      scaling_behavior = "DEFAULT"
      respond_to_afd   = "NONE"
      sharpness        = 50

      codec_settings {
        h264_settings {
          rate_control_mode     = "QVBR"
          qvbr_quality_level    = 7
          max_bitrate           = 3000000
          framerate_control     = "SPECIFIED"
          framerate_numerator   = 30
          framerate_denominator = 1
          gop_size              = 2
          gop_size_units        = "SECONDS"
          gop_closed_cadence    = 1
          gop_num_b_frames      = 2
          profile               = "HIGH"
          level                 = "H264_LEVEL_AUTO"
          scene_change_detect   = "ENABLED"
          par_control           = "INITIALIZE_FROM_SOURCE"
        }
      }
    }

    video_descriptions {
      name             = "video_480"
      width            = 854
      height           = 480
      scaling_behavior = "DEFAULT"
      respond_to_afd   = "NONE"
      sharpness        = 50

      codec_settings {
        h264_settings {
          rate_control_mode     = "QVBR"
          qvbr_quality_level    = 6
          max_bitrate           = 1500000
          framerate_control     = "SPECIFIED"
          framerate_numerator   = 30
          framerate_denominator = 1
          gop_size              = 2
          gop_size_units        = "SECONDS"
          gop_closed_cadence    = 1
          gop_num_b_frames      = 2
          profile               = "MAIN"
          level                 = "H264_LEVEL_AUTO"
          scene_change_detect   = "ENABLED"
          par_control           = "INITIALIZE_FROM_SOURCE"
        }
      }
    }

    output_groups {
      name = "hls"

      output_group_settings {
        hls_group_settings {
          mode              = "LIVE"
          output_selection  = "MANIFESTS_AND_SEGMENTS"
          segment_length    = var.segment_seconds
          input_loss_action = "EMIT_OUTPUT"

          destination {
            destination_ref_id = "mp2"
          }

          hls_cdn_settings {
            hls_basic_put_settings {
              connection_retry_interval = 5
              num_retries               = 5
              restart_delay             = 15
              filecache_duration        = 300
            }
          }
        }
      }

      # single audio track flagged as the default, otherwise players leave it unselected and you get no sound
      outputs {
        output_name             = "audio"
        audio_description_names = ["audio_aac"]

        output_settings {
          hls_output_settings {
            name_modifier = "_audio"
            hls_settings {
              audio_only_hls_settings {
                audio_group_id   = "program_audio"
                audio_track_type = "ALTERNATE_AUDIO_AUTO_SELECT_DEFAULT"
                segment_type     = "AAC"
              }
            }
          }
        }
      }

      # the three video rungs, all sharing that one audio group
      outputs {
        output_name            = "o1080"
        video_description_name = "video_1080"

        output_settings {
          hls_output_settings {
            name_modifier = "_1080"
            hls_settings {
              standard_hls_settings {
                audio_rendition_sets = "program_audio"
                m3u8_settings {
                  audio_frames_per_pes    = 4
                  pat_interval            = 0
                  pcr_control             = "PCR_EVERY_PES_PACKET"
                  pmt_interval            = 0
                  scte35_behavior         = "NO_PASSTHROUGH"
                  timed_metadata_behavior = "NO_PASSTHROUGH"
                }
              }
            }
          }
        }
      }

      outputs {
        output_name            = "o720"
        video_description_name = "video_720"

        output_settings {
          hls_output_settings {
            name_modifier = "_720"
            hls_settings {
              standard_hls_settings {
                audio_rendition_sets = "program_audio"
                m3u8_settings {
                  audio_frames_per_pes    = 4
                  pat_interval            = 0
                  pcr_control             = "PCR_EVERY_PES_PACKET"
                  pmt_interval            = 0
                  scte35_behavior         = "NO_PASSTHROUGH"
                  timed_metadata_behavior = "NO_PASSTHROUGH"
                }
              }
            }
          }
        }
      }

      outputs {
        output_name            = "o480"
        video_description_name = "video_480"

        output_settings {
          hls_output_settings {
            name_modifier = "_480"
            hls_settings {
              standard_hls_settings {
                audio_rendition_sets = "program_audio"
                m3u8_settings {
                  audio_frames_per_pes    = 4
                  pat_interval            = 0
                  pcr_control             = "PCR_EVERY_PES_PACKET"
                  pmt_interval            = 0
                  scte35_behavior         = "NO_PASSTHROUGH"
                  timed_metadata_behavior = "NO_PASSTHROUGH"
                }
              }
            }
          }
        }
      }
    }
  }

  depends_on = [awscc_mediapackagev2_channel_policy.main]
}
