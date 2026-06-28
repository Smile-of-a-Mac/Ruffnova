//! Quick SWF analyzer — dumps tags from a SWF file.
use std::fs::File;
use std::io::BufReader;
use std::path::PathBuf;

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 2 {
        eprintln!("Usage: analyze_swf <file.swf>");
        std::process::exit(1);
    }
    let path = PathBuf::from(&args[1]);
    let file = File::open(&path).unwrap();
    let reader = BufReader::new(file);
    let swf_buf = swf::decompress_swf(reader).unwrap();
    let swf = swf::parse_swf(&swf_buf).unwrap();

    println!("=== SWF Analysis: {} ===", path.file_name().unwrap().to_string_lossy());
    println!("SWF Version: {}", swf.header.version());
    println!("Stage Size: {}x{}", swf.header.stage_size().width().to_pixels(), swf.header.stage_size().height().to_pixels());
    println!("Frame Rate: {:.1} fps", swf.header.frame_rate());
    println!("Number of Frames: {}", swf.header.num_frames());
    println!("Number of Tags: {}", swf.tags.len());
    println!();

    println!("=== Complete Tag List ===");
    for (i, tag) in swf.tags.iter().enumerate() {
        let desc = describe_tag(tag);
        println!("  [{:3}] {}", i, desc);
    }
}

fn describe_tag(tag: &swf::Tag) -> String {
    match tag {
        swf::Tag::End => "End".into(),
        swf::Tag::ShowFrame => "ShowFrame".into(),
        swf::Tag::SetBackgroundColor(rgb) => format!("SetBackgroundColor #{:06X}", rgb),
        swf::Tag::PlaceObject(p) => format!("PlaceObject depth={}", p.depth),
        swf::Tag::PlaceObject2(p) => format!("PlaceObject2 depth={} char={:?} name={:?}", p.depth, p.character_id, p.name),
        swf::Tag::PlaceObject3(p) => format!("PlaceObject3 depth={} char={:?} name={:?}", p.depth, p.character_id, p.name),
        swf::Tag::RemoveObject(depth) => format!("RemoveObject depth={}", depth),
        swf::Tag::RemoveObject2(depth) => format!("RemoveObject2 depth={}", depth),
        swf::Tag::DefineShape(s) => format!("DefineShape id={}", s.0.id),
        swf::Tag::DefineShape2(s) => format!("DefineShape2 id={}", s.0.id),
        swf::Tag::DefineShape3(s) => format!("DefineShape3 id={}", s.0.id),
        swf::Tag::DefineShape4(s) => format!("DefineShape4 id={}", s.0.id),
        swf::Tag::DefineMorphShape(s) => format!("DefineMorphShape id={}", s.0.id),
        swf::Tag::DefineMorphShape2(s) => format!("DefineMorphShape2 id={}", s.0.id),
        swf::Tag::DefineSprite(s) => format!("DefineSprite id={} frames={} tags={}", s.0.id, s.0.frames, s.0.tags.len()),
        swf::Tag::DefineButton(c) => format!("DefineButton id={}", c.0.id),
        swf::Tag::DefineButton2(c) => format!("DefineButton2 id={} track_as_menu={} actions={}", c.0.id, c.0.track_as_menu, c.0.actions.len()),
        swf::Tag::DefineButtonColorTransform(id, _) => format!("DefineButtonColorTransform id={}", id),
        swf::Tag::DefineEditText(t) => format!("DefineEditText id={} var='{}' initial='{}'", t.id, t.variable_name, t.initial_text.as_deref().unwrap_or("")),
        swf::Tag::DefineText(t) => format!("DefineText id={}", t.id),
        swf::Tag::DefineText2(t) => format!("DefineText2 id={}", t.id),
        swf::Tag::DefineFontInfo(f) => format!("DefineFontInfo id={} name='{}'", f.font_id, f.name),
        swf::Tag::DefineFont(f) => format!("DefineFont id={}", f.0.id),
        swf::Tag::DefineFont2(f) => format!("DefineFont2 id={} name='{}'", f.0.id, f.0.name),
        swf::Tag::DefineFont4(f) => format!("DefineFont4 id={} name='{}'", f.0.id, f.0.name),
        swf::Tag::DefineSound(s) => format!("DefineSound id={} fmt={:?} rate={} samples={}", s.0.id, s.0.format, s.0.sample_rate, s.0.sample_count),
        swf::Tag::DefineVideoStream(s) => format!("DefineVideoStream id={}", s.0.id),
        swf::Tag::VideoFrame(v) => format!("VideoFrame stream={} num={}", v.stream_id, v.frame_num),
        swf::Tag::DefineBinaryData(b) => format!("DefineBinaryData id={} ({} bytes)", b.0.id, b.0.data.len()),
        swf::Tag::SymbolClass(symbols) => {
            let mut s = String::from("SymbolClass:");
            for link in symbols {
                s.push_str(&format!(" [{} -> {}]", link.id, link.name));
            }
            s
        }
        swf::Tag::ExportAssets(exports) => {
            let mut s = String::from("ExportAssets:");
            for (id, name) in exports {
                s.push_str(&format!(" [{} -> {}]", id, name));
            }
            s
        }
        swf::Tag::DoAbc(data) => format!("DoAbc {} bytes", data.len()),
        swf::Tag::DoAbc2(data) => format!("DoAbc2 name='{}' flags={} data={} bytes", data.name, data.flags, data.data.len()),
        swf::Tag::Metadata(data) => format!("Metadata: {}", String::from_utf8_lossy(data)),
        swf::Tag::FileAttributes(attrs) => format!("FileAttributes: useNetwork={} hasMetadata={} hasImport={} hasExport={} directBlit={} gpu={}", attrs.use_network, attrs.has_metadata, attrs.has_import, attrs.has_export, attrs.direct_blit, attrs.supports_gpu),
        swf::Tag::DebugId(data) => format!("DebugId: {}", hex_encode(data)),
        swf::Tag::Protect(_) => "Protect".into(),
        swf::Tag::ImportAssets(imports) => format!("ImportAssets: {} imports", imports.len()),
        swf::Tag::ImportAssets2(url, imports) => format!("ImportAssets2 url='{}' ({} imports)", url, imports.len()),
        swf::Tag::EnableTelemetry(_) => "EnableTelemetry".into(),
        swf::Tag::ScriptLimits(max_recursion, script_timeout) => format!("ScriptLimits: maxRecursion={} timeout={}", max_recursion, script_timeout),
        swf::Tag::DefineSceneAndFrameLabelData(scenes) => format!("DefineSceneAndFrameLabelData: {} scenes", scenes.len()),
        swf::Tag::DefineScalingGrid(id, _) => format!("DefineScalingGrid id={}", id),
        swf::Tag::SoundStreamHead(h) => format!("SoundStreamHead: playback={:?} stream_samples={}", h.playback_rate, h.stream_sample_count),
        swf::Tag::SoundStreamHead2(h) => format!("SoundStreamHead2: playback={:?} stream_samples={}", h.playback_rate, h.stream_sample_count),
        swf::Tag::SoundStreamBlock(_) => "SoundStreamBlock".into(),
        swf::Tag::StartSound(id, _) => format!("StartSound id={}", id),
        swf::Tag::StartSound2(id) => format!("StartSound2 id={}", id),
        swf::Tag::FrameLabel(label) => format!("FrameLabel: '{}'", label),
        swf::Tag::DefineBitsLossless(_) => "DefineBitsLossless".into(),
        swf::Tag::DefineBitsLossless2(_) => "DefineBitsLossless2".into(),
        swf::Tag::DefineBitsJpeg(_) => "DefineBitsJpeg".into(),
        swf::Tag::DefineBitsJpeg2(_) => "DefineBitsJpeg2".into(),
        swf::Tag::DefineBitsJpeg3(j) => format!("DefineBitsJpeg3 id={} ({} bytes)", j.0.id, j.0.data.len()),
        swf::Tag::DefineBitsJpeg4(j) => format!("DefineBitsJpeg4 id={} ({} bytes)", j.0.id, j.0.data.len()),
        swf::Tag::JPEGTables(_) => "JPEGTables".into(),
        swf::Tag::DefineBits(_) => "DefineBits".into(),
        swf::Tag::Unknown { tag_code, length } => format!("Unknown tag_code={} length={}", tag_code, length),
        _ => format!("{:?}", std::mem::discriminant(tag)),
    }
}

fn hex_encode(data: &[u8]) -> String {
    data.iter().map(|b| format!("{:02X}", b)).collect()
}
