import java.io.*;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.security.MessageDigest;
import java.util.*;
import java.util.regex.*;
import java.util.zip.*;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.transform.TransformerFactory;
import javax.xml.transform.dom.DOMSource;
import javax.xml.transform.stream.StreamResult;
import org.w3c.dom.Document;

/** AIR build and demo bootstrap. Uses only the JDK and Ant that launches it. */
public final class Demo {
    private static final String VERSION = "51.4.1.2";
    private static final boolean MAC = System.getProperty("os.name").startsWith("Mac");
    private static final boolean WINDOWS = System.getProperty("os.name").startsWith("Windows");
    private static final List<Process> CHILDREN = Collections.synchronizedList(new ArrayList<>());
    private final Path root, output;
    private final int screens, width, height, port;
    private final String sync;

    private Demo(String[] args) {
        root = Path.of(args[1]).toAbsolutePath();
        output = root.resolve("demo-build");
        screens = Integer.parseInt(args[3]);
        width = Integer.parseInt(args[4]);
        height = Integer.parseInt(args[5]);
        port = Integer.parseInt(args[6]);
        sync = args[7];
        require(screens >= 1 && screens <= 10, "demo.screens must be between 1 and 10.");
        require(width >= 400 && height >= 240, "Use demo.width >= 400 and demo.height >= 240.");
        require(port > 0 && port + screens - 1 <= 65535, "Invalid UDP port range.");
        require(sync.equals("frame") || sync.equals("time"), "demo.sync must be frame or time.");
    }

    public static void main(String[] args) {
        Runtime.getRuntime().addShutdownHook(new Thread(Demo::stopChildren));
        try {
            require(MAC || WINDOWS, "The local demo supports macOS and Windows.");
            Demo demo = new Demo(args);
            require(!args[0].equals("check") || demo.sync.equals("frame"), "demo-check uses frame sync.");
            Path sdk = demo.sdk(args[2]);
            if (args[0].equals("library")) {
                Path library = demo.root.resolve("lib-release/FlashSpan.swc");
                demo.compileLibrary(sdk, library, false);
                System.out.println("Built release library: " + library);
            } else {
                demo.build(sdk);
                if (!args[0].equals("build")) demo.launch(sdk, args[0].equals("check"));
            }
        } catch (Exception e) {
            System.err.println("FlashSpan: " + e.getMessage());
            stopChildren();
            System.exit(1);
        }
    }

    private Path sdk(String override) throws Exception {
        String configured = override.isBlank() ? System.getenv("AIR_SDK_HOME") : override;
        if (configured != null && !configured.isBlank()) {
            Path sdk = Path.of(configured).toAbsolutePath();
            validateSdk(sdk);
            return sdk;
        }
        String platform = MAC ? "MacOS" : "Windows";
        String hash = MAC
            ? "e2816427b8e3c77240bc4d413f80330c9d7436b057458125c57bc659a71a5c25"
            : "8476c4c93b70dc88d3a07e43bfa98074c990a43fcbe8729d1449b88bed953f5b";
        Path sdk = root.resolve(".tools/air-sdk-" + VERSION + "-" + platform);
        Path marker = sdk.resolve(".flashspan-sdk-ready");
        if (!Files.isRegularFile(marker)) {
            Path archive = root.resolve(".tools/downloads/AIRSDK-" + VERSION + "-" + platform + ".zip");
            download("https://airsdk.wxlift.com/api/versions/" + VERSION
                + "/sdks/AIRSDK_" + platform + ".zip?license=accepted", archive, hash);
            System.out.println("Extracting AIR SDK " + VERSION + " (first run only)...");
            Files.createDirectories(sdk);
            if (MAC) {
                // Native unzip preserves the framework symlinks and executable permissions.
                run(Arrays.asList("/usr/bin/unzip", "-q", "-o", archive.toString(), "-d", sdk.toString()));
            } else {
                try (ZipInputStream zip = new ZipInputStream(Files.newInputStream(archive))) {
                    ZipEntry entry;
                    while ((entry = zip.getNextEntry()) != null) {
                        Path dest = sdk.resolve(entry.getName()).normalize();
                        require(dest.startsWith(sdk), "Unsafe SDK archive entry: " + entry.getName());
                        if (entry.isDirectory()) Files.createDirectories(dest);
                        else {
                            Files.createDirectories(dest.getParent());
                            Files.copy(zip, dest, StandardCopyOption.REPLACE_EXISTING);
                        }
                    }
                }
            }
            validateSdk(sdk);
            Files.writeString(marker, VERSION + "\n");
            System.out.println("AIR SDK license: " + sdk.resolve("AIR SDK license.pdf"));
        }
        validateSdk(sdk);
        return sdk;
    }

    private void validateSdk(Path sdk) {
        require(Files.isRegularFile(sdk.resolve("lib/mxmlc-cli.jar"))
            && Files.isRegularFile(sdk.resolve("lib/compc-cli.jar"))
            && Files.isRegularFile(sdk.resolve("frameworks/air-config.xml"))
            && Files.isRegularFile(adl(sdk)),
            "Full AIR SDK required at " + sdk + ". Use the ActionScript SDK, rather than the Flex overlay or runtime.");
    }

    private static Path adl(Path sdk) {
        return sdk.resolve(WINDOWS ? "bin/adl64.exe" : "bin/adl");
    }

    private static void download(String url, Path dest, String expectedHash) throws Exception {
        Files.createDirectories(dest.getParent());
        if (Files.isRegularFile(dest) && sha256(dest).equals(expectedHash)) return;
        Path partial = dest.resolveSibling(dest.getFileName() + ".part");
        System.out.println("Downloading AIR SDK " + VERSION + " (~600 MB; cached in .tools)."
            + "\nDownload and license information: https://airsdk.wxlift.com/download");
        try {
            URLConnection connection = URI.create(url).toURL().openConnection();
            connection.setConnectTimeout(30000);
            connection.setReadTimeout(60000);
            try (InputStream input = connection.getInputStream();
                 OutputStream output = Files.newOutputStream(partial)) {
                byte[] buffer = new byte[1024 * 1024];
                long downloaded = 0, reported = 0;
                int read;
                while ((read = input.read(buffer)) != -1) {
                    output.write(buffer, 0, read);
                    downloaded += read;
                    if (downloaded - reported >= 64L * 1024 * 1024) {
                        System.out.println("  " + downloaded / (1024 * 1024) + " MB downloaded");
                        reported = downloaded;
                    }
                }
            }
            require(sha256(partial).equals(expectedHash), "AIR SDK checksum mismatch; rerun to download again.");
            Files.move(partial, dest, StandardCopyOption.REPLACE_EXISTING);
        } finally {
            Files.deleteIfExists(partial);
        }
    }

    private static String sha256(Path path) throws Exception {
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        try (InputStream stream = Files.newInputStream(path)) {
            byte[] buffer = new byte[1024 * 1024];
            int read;
            while ((read = stream.read(buffer)) != -1) digest.update(buffer, 0, read);
        }
        StringBuilder hex = new StringBuilder();
        for (byte b : digest.digest()) hex.append(String.format("%02x", b & 255));
        return hex.toString();
    }

    private void build(Path sdk) throws Exception {
        Files.createDirectories(output);
        System.out.println("Building FlashSpan and the demo with AIR " + sdk + "...");
        compileLibrary(sdk, output.resolve("FlashSpan.swc"), true);
        List<String> example = compiler(sdk, "mxmlc", true);
        example.add("-source-path+=" + root.resolve("third-party/minimalcomps/src"));
        example.add("-library-path+=" + output.resolve("FlashSpan.swc"));
        example.add("-default-frame-rate=60");
        example.add("-default-size=" + width + "," + height);
        example.add("-output=" + output.resolve("FlashSpanExample.swf"));
        example.add(root.resolve("FlashSpanExample/src/FlashSpanExample.as").toString());
        run(example);
        for (int id = 0; id < screens; id++) prepareScreen(id);
        System.out.println("Built " + screens + " screens in " + output);
    }

    private void compileLibrary(Path sdk, Path destination, boolean debug) throws Exception {
        Files.createDirectories(destination.getParent());
        List<String> library = compiler(sdk, "compc", debug);
        library.add("-source-path+=" + root.resolve("third-party/as3commons-logging/src"));
        library.add("-include-sources=" + root.resolve("FlashSpanLibrary/src"));
        library.add("-output=" + destination);
        run(library);
    }

    private List<String> compiler(Path sdk, String tool, boolean debug) {
        return new ArrayList<>(Arrays.asList(
            Path.of(System.getProperty("java.home"), "bin", WINDOWS ? "java.exe" : "java").toString(),
            "-Dflexlib=" + sdk.resolve("frameworks"), "-jar", sdk.resolve("lib/" + tool + "-cli.jar").toString(),
            "+configname=air", "-debug=" + debug));
    }

    private void prepareScreen(int id) throws Exception {
        Path screen = output.resolve("screen-" + id);
        Files.createDirectories(screen);
        Files.copy(output.resolve("FlashSpanExample.swf"), screen.resolve("FlashSpanExample.swf"), StandardCopyOption.REPLACE_EXISTING);
        Files.copy(root.resolve("third-party/minimalcomps/LICENSE.txt"), screen.resolve("MinimalComps-LICENSE.txt"), StandardCopyOption.REPLACE_EXISTING);
        Files.copy(root.resolve("third-party/minimalcomps/FONT-NOTICE.txt"), screen.resolve("MinimalComps-FONT-NOTICE.txt"), StandardCopyOption.REPLACE_EXISTING);
        Document descriptor = DocumentBuilderFactory.newInstance().newDocumentBuilder()
            .parse(root.resolve("FlashSpanExample/src/FlashSpanExample-app.xml").toFile());
        String[][] fields = {
            {"id", "com.kitschpatrol.flashspan.example" + id}, {"filename", "FlashSpanExample" + id},
            {"name", "FlashSpan Example " + id}, {"title", "FlashSpan / Screen " + id},
            {"width", Integer.toString(width)}, {"height", Integer.toString(height)},
            {"x", Integer.toString(30 + id * (width + 12))}, {"y", "60"}
        };
        for (String[] field : fields) descriptor.getElementsByTagName(field[0]).item(0).setTextContent(field[1]);
        TransformerFactory.newInstance().newTransformer().transform(new DOMSource(descriptor),
            new StreamResult(screen.resolve("FlashSpanExample-app.xml").toFile()));
        StringBuilder settings = new StringBuilder("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<settings>\n"
            + "  <screenWidth>" + width + "</screenWidth>\n  <screenHeight>" + height + "</screenHeight>\n"
            + "  <bezelWidth>0</bezelWidth>\n  <server>auto</server>\n  <syncMode>" + sync + "</syncMode>\n  <networkMap>\n");
        for (int n = 0; n < screens; n++) settings.append("    <screen><id>").append(n)
            .append("</id><ip>127.0.0.1</ip><port>").append(port + n).append("</port></screen>\n");
        Files.writeString(screen.resolve("flash_span_settings.xml"), settings.append("  </networkMap>\n</settings>\n"));
    }

    private void launch(Path sdk, boolean check) throws Exception {
        // Fail before opening windows if another demo already owns one of these ports.
        List<DatagramSocket> probes = new ArrayList<>();
        try {
            for (int id = 0; id < screens; id++) probes.add(new DatagramSocket(port + id, InetAddress.getByName("127.0.0.1")));
        } catch (SocketException e) {
            throw new IOException("Demo UDP ports are busy. Close the previous demo or set -Ddemo.port=64000.", e);
        } finally {
            for (DatagramSocket probe : probes) probe.close();
        }
        // Launch clients first, then let the server start animation once all are ready.
        for (int n = 1; n <= screens; n++) {
            int id = n % screens;
            Path screen = output.resolve("screen-" + id);
            Process process = new ProcessBuilder(adl(sdk).toString(), "-profile", "extendedDesktop",
                screen.resolve("FlashSpanExample-app.xml").toString(), "--", Integer.toString(id), "--autostart")
                .directory(screen.toFile()).redirectErrorStream(true).redirectOutput(log(id).toFile()).start();
            CHILDREN.add(process);
            awaitLog(id, "READY screen=" + id, 20000);
        }
        System.out.println("Demo running. Click to add balls; controls work across all screens."
            + "\nClose a window, use Quit All, or press Ctrl+C here to stop. Logs: " + output + "/screen-*/adl.log");
        if (check) {
            String reference = null;
            for (int id = 0; id < screens; id++) {
                awaitLog(id, "frame=120 state=", 15000);
                Matcher match = Pattern.compile("frame=120 state=([^\\r\\n]+)").matcher(Files.readString(log(id)));
                require(match.find(), "Missing animation state for screen " + id);
                if (reference == null) reference = match.group(1);
                require(reference.equals(match.group(1)), "Animation state differs on screen " + id);
            }
            send("t");
            for (int id = 0; id < screens; id++) awaitLog(id, "STOP screen=" + id, 5000);
            for (String[] test : new String[][] {{"ec,", "c balls=0"}, {"ea,", "a balls=10"}, {"em,600,200", "m balls=11"}}) {
                for (int id = 0; id < screens; id++) send(test[0], port + id);
                for (int id = 0; id < screens; id++) awaitLog(id, "header=" + test[1], 5000);
            }
            send("s");
            // Repeated Start must not create extra timers or fall through to Stop.
            send("s");
            reference = null;
            for (int id = 0; id < screens; id++) {
                awaitLog(id, "frame=240 state=", 10000);
                Matcher match = Pattern.compile("frame=240 state=([^\\r\\n]+)").matcher(Files.readString(log(id)));
                require(match.find(), "Missing restarted animation state for screen " + id);
                if (reference == null) reference = match.group(1);
                require(reference.equals(match.group(1)), "Restarted animation state differs on screen " + id);
            }
            System.out.println("PASS: " + screens + " AIR windows rendered identical ball states; clear/add/click messages and stop/restart succeeded.");
            stopChildren();
            return;
        }
        while (true) {
            for (Process child : CHILDREN) {
                if (!child.isAlive()) {
                    require(child.exitValue() == 0, "AIR exited with code " + child.exitValue() + ". See " + output + "/screen-*/adl.log");
                    stopChildren();
                    return;
                }
            }
            Thread.sleep(250);
        }
    }

    private void send(String message) throws Exception {
        send(message, port);
    }

    private void send(String message, int destinationPort) throws Exception {
        try (DatagramSocket socket = new DatagramSocket()) {
            byte[] data = message.getBytes(StandardCharsets.UTF_8);
            socket.send(new DatagramPacket(data, data.length, InetAddress.getByName("127.0.0.1"), destinationPort));
        }
    }

    private Path log(int id) { return output.resolve("screen-" + id + "/adl.log"); }

    private void awaitLog(int id, String text, long timeout) throws Exception {
        long deadline = System.nanoTime() + timeout * 1000000;
        while (System.nanoTime() < deadline) {
            String contents = Files.exists(log(id)) ? Files.readString(log(id)) : "";
            require(!contents.contains("Error #") && !contents.contains("Exception"), "AIR error in " + log(id) + ":\n" + contents);
            if (contents.contains(text)) return;
            for (Process child : CHILDREN) require(child.isAlive(), "AIR exited during startup. See " + log(id));
            Thread.sleep(100);
        }
        throw new IOException("Timed out waiting for '" + text + "'. See " + log(id));
    }

    private void run(List<String> command) throws Exception {
        Process process = new ProcessBuilder(command).directory(root.toFile()).inheritIO().start();
        CHILDREN.add(process);
        int code = process.waitFor();
        CHILDREN.remove(process);
        require(code == 0, "Command failed (exit " + code + "): " + String.join(" ", command));
    }

    private static void stopChildren() {
        synchronized (CHILDREN) {
            for (Process child : CHILDREN) if (child.isAlive()) child.destroy();
        }
    }

    private static void require(boolean condition, String message) {
        if (!condition) throw new IllegalArgumentException(message);
    }
}
