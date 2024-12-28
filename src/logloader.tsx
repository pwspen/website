import type {
  LogFile,
  DataSnapshot,
  LogSnapshotProps,
  LogViewerProps,
} from "./types"; // Assuming you've moved interfaces to a types.ts file

import { useEffect, useRef, useState } from "react";
import type { ReactNode } from "react";

interface FullWidthProps {
  children: ReactNode;
  className?: string;
}

function FullWidth({ children, className = "" }: FullWidthProps) {
  return (
    <div
      className={`relative left-1/2 right-1/2 -mx-[50vw] w-screen ${className}`}
    >
      <div className="mx-auto max-w-[100vw] px-4">{children}</div>
    </div>
  );
}

export const loadLogFile = async (
  filename: string
): Promise<DataSnapshot[]> => {
  try {
    // Dynamically import the JSON file
    const logFile: LogFile = await fetch(filename).then((res) => res.json());

    // Validate the structure
    if (!logFile.snapshots || !Array.isArray(logFile.snapshots)) {
      throw new Error("Invalid log file format");
    }

    // Ensure all snapshots have required fields
    const validSnapshots = logFile.snapshots.map((snapshot, index) => {
      if (!snapshot.timestamp) {
        console.warn(
          `Snapshot ${index} missing timestamp, using index as timestamp`
        );
        snapshot.timestamp = index;
      }
      if (!snapshot.id) {
        snapshot.id = index;
      }
      if (!snapshot.data) {
        snapshot.data = {};
      }
      return snapshot;
    });

    return validSnapshots;
  } catch (error) {
    console.error("Error loading log file:", error);
    return [];
  }
};

export const LogSnapshot: React.FC<LogSnapshotProps> = ({
  snapshot,
  formatTimestamp = (timestamp: number) =>
    new Date(timestamp).toLocaleTimeString(),
}) => {
  return (
    <div className="inline-block w-96 bg-white rounded-xl shadow-lg overflow-hidden">
      <div className="p-3 bg-gray-50 border-b text-sm text-gray-600">
        {formatTimestamp(snapshot.timestamp)}
      </div>

      {snapshot.image && (
        <div className="p-4">
          <img
            src={snapshot.image}
            alt={`Snapshot ${snapshot.id}`}
            className="w-full h-48 object-cover rounded-lg"
          />
        </div>
      )}

      <div className="p-4 space-y-3 max-h-96 overflow-y-auto">
        {Object.entries(snapshot.data).map(([key, value]) => (
          <div
            key={key}
            className="bg-gray-50 p-3 rounded-lg break-words whitespace-normal"
          >
            <div className="font-medium text-gray-700">{key}</div>
            <div className="text-gray-600 break-words">
              {value?.toString() || "No data"}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};

export const LogViewer: React.FC<LogViewerProps> = ({
  snapshots = [],
  mode = "live",
  playbackDelay = 1000,
  logs_fpath,
}) => {
  const [isPlaying, setIsPlaying] = useState(false);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [loadedSnapshots, setLoadedSnapshots] = useState<DataSnapshot[]>([]);
  const scrollContainerRef = useRef<HTMLDivElement>(null);

  const activeSnapshots = logs_fpath ? loadedSnapshots : snapshots;
  const visibleSnapshots =
    mode === "live"
      ? activeSnapshots
      : activeSnapshots.slice(0, currentIndex + 1);

  useEffect(() => {
    if (mode === "live" && logs_fpath) {
      throw new Error("Cannot provide logs_fpath in live mode");
    }

    const loadData = async () => {
      if (mode === "playback" && logs_fpath) {
        const loaded = await loadLogFile(logs_fpath);
        setLoadedSnapshots(loaded);
        setCurrentIndex(0);
        setIsPlaying(false);
      }
    };

    loadData();
  }, [mode, logs_fpath]);

  // For live mode: scroll to the right when new data arrives
  useEffect(() => {
    if (scrollContainerRef.current) {
      scrollContainerRef.current.scrollLeft =
        scrollContainerRef.current.scrollWidth;
    }
  }, [visibleSnapshots.length]);

  // Playback logic
  useEffect(() => {
    if (mode === "playback" && isPlaying) {
      const activeSnapshots = logs_fpath ? loadedSnapshots : snapshots;
      const intervalId = setInterval(() => {
        setCurrentIndex((prevIndex) => {
          if (prevIndex >= activeSnapshots.length - 1) {
            setIsPlaying(false);
            return prevIndex;
          }
          return prevIndex + 1;
        });
      }, playbackDelay);

      return () => clearInterval(intervalId);
    }
  }, [
    isPlaying,
    playbackDelay,
    mode,
    snapshots.length,
    loadedSnapshots.length,
    logs_fpath,
  ]);

  const togglePlayback = () => {
    const activeSnapshots = logs_fpath ? loadedSnapshots : snapshots;
    if (!isPlaying && currentIndex >= activeSnapshots.length - 1) {
      setCurrentIndex(0); // Reset to start when reaching the end
    }
    setIsPlaying(!isPlaying);
  };

  return (
    <FullWidth>
      <div className="h-full">
        {mode === "playback" && (
          <div className="flex items-center justify-center mb-4">
            <button
              onClick={togglePlayback}
              className="bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600"
            >
              {isPlaying ? "Pause" : "Play"}
            </button>
            <div className="ml-4 text-gray-600">
              Showing {currentIndex + 1} of {activeSnapshots.length} snapshots
            </div>
          </div>
        )}
        <div
          ref={scrollContainerRef}
          className="h-full overflow-x-auto whitespace-nowrap"
          style={{ scrollBehavior: "smooth" }}
        >
          <div className="inline-flex gap-4 p-4">
            {visibleSnapshots.map((snapshot) => (
              <LogSnapshot key={snapshot.id} snapshot={snapshot} />
            ))}
          </div>
        </div>
      </div>
    </FullWidth>
  );
};
