import SwiftUI

struct PhoneContentView: View {
    @EnvironmentObject var connectivity: PhoneConnectivityManager

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)

                Text("drunk relay")
                    .font(.largeTitle.bold())

                VStack(spacing: 8) {
                    row(label: "Watch", value: connectivity.watchStatus)
                    row(label: "Server", value: connectivity.serverStatus)
                    row(label: "Last sync", value: connectivity.lastSyncTime)
                    row(label: "Events relayed", value: "\(connectivity.totalRelayed)")
                }
                .padding()
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding()
            .navigationTitle("drunk")
        }
    }

    private func row(label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).bold()
        }
    }
}
