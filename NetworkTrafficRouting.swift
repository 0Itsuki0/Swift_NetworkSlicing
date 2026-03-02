
import CoreTelephony
import SwiftUI

@Observable
class NetworkTrafficManager {

    private(set) var availableSliceAppCategories:
        [CTSlicingManager.AppCategory] = []
    private(set) var enabledSlicingCategory: CTSlicingManager.AppCategory? = nil

    private(set) var activeSlices: [CTSlicingManager.Slice] = []

    private let slicingManager = CTSlicingManager.shared

    init() {
        self.fetchAvailableCategories()
        self.fetchActiveSlices()
    }

    // Network-slicing app categories available to the app
    // This property returns an array of CTSlicingManager.AppCategory values that meet all of the following requirements:
    // - The carrier’s network supports them.
    // - The app’s entitlements (5G Network Slicing App Category & 5G Network Slicing Traffic Category) include them.
    // - The device and network currently make them available.
    func fetchAvailableCategories() {
        Task {
            do {
                self.availableSliceAppCategories =
                    try await CTSlicingManager.shared
                    .availableSliceAppCategories
            } catch(let error) {
                self.handleError(error)
            }
        }
    }

    // fetch Information about currently active network slices on the device
    // Use this function to validate that the preferred slice activates successfully.
    //
    // To monitor for changes, use a timer and poll on the activeSlices property
    func fetchActiveSlices() {
        Task {
            do {
                self.activeSlices = try await self.slicingManager.activeSlices
            } catch(let error) {
                self.handleError(error)
            }
        }
    }

    // Activates a preferred network slice for new connections
    func activateSliceForCategory(_ category: CTSlicingManager.AppCategory) {
        guard self.availableSliceAppCategories.contains(category) else {
            return
        }
        guard self.enabledSlicingCategory == nil else {
            return
        }
        Task {
            do {
                try await self.slicingManager.activatePreferredSliceForCategory(
                    category
                )
                self.enabledSlicingCategory = category
                // refetch active slices since we have made some changes.
                self.fetchActiveSlices()
            } catch(let error) {
                self.handleError(error)
            }
        }
    }

    // stop using network slicing
    //  After calling this method, new network connections that your app establishes use the carrier’s default cellular internet without slice-specific routing.
    func stopSlicing() {
        Task {
            do {
                try await self.slicingManager.disableSlicing()
                self.enabledSlicingCategory = nil
                self.fetchActiveSlices()
            } catch(let error) {
                self.handleError(error)
            }
        }
    }
    
    private func handleError(_ error: Error) {
        if let error = error as? POSIXError {
            switch error.code {
            case .ENOTSUP:
                print("Network slicing isn't currently available")
                return
            case .EINVAL:
                print("Invalid parameter or system error occurs")
                return
            default:
                break
            }
        }
        print("Error performing request: \(error)")
    }

}

extension CTSlicingManager.AppCategory {
    var title: String {
        switch self {
        case .gaming:
            "Gaming"
        case .communication:
            "Communication"
        case .streaming:
            "Streaming"
        @unknown default:
            "Unknown"
        }
    }
}

extension CTSlicingManager.TrafficClass {
    var title: String {
        switch self {
        case .any:
            "Any"
        case .background:
            "Background"
        case .responsiveData:
            "Responsive Data"
        case .avStreaming:
            "AV Streaming"
        case .responsiveAV:
            "Responsive AV"
        case .video:
            "Video"
        case .voice:
            "Voice"
        case .signaling:
            "Signaling"
        @unknown default:
            "Unknown"
        }
    }
}

struct NetworkTrafficRoutingDemo: View {
    @State private var networkTrafficManager = NetworkTrafficManager()

    var body: some View {
        NavigationStack {
            List {
                Section("Slicing App Categories Available") {
                    if networkTrafficManager.availableSliceAppCategories.isEmpty
                    {
                        Text(
                            "No Network-slicing app categories available to the app."
                        )
                        .foregroundStyle(.secondary)
                    }
                    ForEach(
                        networkTrafficManager.availableSliceAppCategories,
                        id: \.rawValue
                    ) { category in
                        HStack {
                            Text(category.title)

                            Spacer()

                            if self.networkTrafficManager.enabledSlicingCategory
                                == category
                            {
                                Button(
                                    action: {
                                        self.networkTrafficManager.stopSlicing()
                                    },
                                    label: {
                                        Text("De-Activate")
                                    }
                                )
                            } else {
                                Button(
                                    action: {
                                        self.networkTrafficManager
                                            .activateSliceForCategory(category)
                                    },
                                    label: {
                                        Text("Activate")
                                    }
                                )
                            }
                        }
                    }
                }

                Section("Active Network Slice") {
                    if networkTrafficManager.activeSlices.isEmpty {
                        Text("No Network slice currently active on the device.")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(
                        networkTrafficManager.activeSlices,
                        id: \.networkInterfaceName
                    ) { slice in
                        VStack(
                            alignment: .leading,
                            spacing: 8,
                            content: {
                                Text("Interface: \(slice.networkInterfaceName)")
                                Text(
                                    "Traffic Class: \(slice.trafficClass?.title, default: "Unkown")"
                                )
                                Text("Category: \(slice.appCategory.title)")
                            }
                        )
                    }
                }
            }
            .navigationTitle("Network Traffic Routing")
            .navigationBarTitleDisplayMode(.inline)
        }

    }
}
