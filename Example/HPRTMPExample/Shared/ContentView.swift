//
//  ContentView.swift
//  Shared
//
//  Created by Huiping Guo on 2022/10/22.
//

import SwiftUI

struct ContentView: View {
  
  private var rtmpService = RTMPService()
  @State private var buttonState = "Publish"
  
  var body: some View {
    VStack {
      Text("Hello, world!")
        .padding()
      
      Button(action: {
        Task {
          if buttonState == "Publish" {
            await rtmpService.run()
            buttonState = "Stop"
          } else {
            await rtmpService.stop()
            buttonState = "Publish"
          }
        }
      }) {
        Text(buttonState)
      }
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}
