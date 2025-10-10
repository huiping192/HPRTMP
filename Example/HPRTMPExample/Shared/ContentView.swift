//
//  ContentView.swift
//  Shared
//
//  Created by Huiping Guo on 2022/10/22.
//

import SwiftUI
import Combine

class ViewModel: ObservableObject {
  @Published var isServiceRunning: Bool = false
  var cancellables = Set<AnyCancellable>()
  
  @MainActor
  func subscribeToRTMPService(rtmpService: RTMPService) {
    rtmpService.isRunningSubject
      .receive(on: DispatchQueue.main)
      .sink { [weak self] newValue in
        self?.isServiceRunning = newValue
      }
      .store(in: &cancellables)
  }
}

struct ContentView: View {
  @StateObject private var rtmpService = RTMPService()
  @StateObject private var viewModel = ViewModel()
  
  var body: some View {
    VStack {
      Text(viewModel.isServiceRunning ? "Broadcast starting" : "Broadcast finished")
        .padding()
      
      Button(action: {
        Task {
          if viewModel.isServiceRunning {
            await rtmpService.stop()
          } else {
            await rtmpService.run()
          }
        }
      }) {
        Text(viewModel.isServiceRunning ? "Stop" : "Publish")
      }
    }.onAppear {
      viewModel.subscribeToRTMPService(rtmpService: rtmpService)
    }
  }
}


struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}
