import SwiftUI

struct WikiView: View {
    // We will pass the project in later to fetch wiki pages
    // var project: ProjectItem

    var body: some View {
        VStack {
            Text("Wiki") // Updated Title
                .font(.largeTitle)
                .padding()
            
            Text("This area will contain interconnected pages for worldbuilding, locations, magic systems, etc.")
                .font(.title2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct WikiView_Previews: PreviewProvider { // Updated Preview name
    static var previews: some View {
        WikiView()
    }
}
