//
//  ContentView.swift
//  Shared
//
//  Created by Huiping Guo on 2022/10/22.
//

import SwiftUI

struct ContentView: View {

  let rtmpService = RTMPService()

    var body: some View {
        Text("Hello, world!")
        .padding().onAppear(perform: {
          rtmpService.run()
        })
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
