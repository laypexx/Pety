//
//  ContentView.swift
//  CatFeeder
//
//  Created by dsprenger on 28.03.25.
//

import SwiftUI
import UserNotifications

// MARK: - Pet Model
struct Pet: Codable {
    var name: String
    var emoji: String
    var notificationsEnabled: Bool
}

// MARK: - Main View
struct ContentView: View {
    @AppStorage("isFirstLaunch") private var isFirstLaunch = true
    @AppStorage("pet") private var petData: Data = Data()
    
    @State private var currentPet: Pet?

    var body: some View {
        Group {
            if isFirstLaunch || currentPet == nil {
                OnboardingView(
                    isFirstLaunch: $isFirstLaunch,
                    currentPet: $currentPet,
                    petData: $petData
                )
            } else {
                MainTabView(
                    currentPet: $currentPet,
                    petData: $petData
                )
            }
        }
        .onAppear {
            loadPet()
        }
    }
    
    private func loadPet() {
        guard let pet = try? JSONDecoder().decode(Pet.self, from: petData) else { return }
        currentPet = pet
    }
}


// MARK: - Onboarding View
struct OnboardingView: View {
    @Binding var isFirstLaunch: Bool
    @Binding var currentPet: Pet?
    @Binding var petData: Data
    
    @State private var petName = ""
    @State private var selectedEmoji = "🐱"
    let availableEmojis = ["🐱", "🐶", "🐰", "🐻", "🐯", "🦊", "🐹", "🐮"]
    
    var body: some View {
        VStack(spacing: 30) {
            Text("hi.\r\nWähle dein Haustier!")
                .font(.largeTitle.bold())
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4)) {
                ForEach(availableEmojis, id: \.self) { emoji in
                    Text(emoji)
                        .font(.system(size: 40))
                        .padding()
                        .background(selectedEmoji == emoji ? .blue.opacity(0.3) : .clear)
                        .cornerRadius(10)
                        .onTapGesture {
                            selectedEmoji = emoji
                        }
                }
            }
            .padding()
            
            TextField("Name des Haustiers", text: $petName)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 30)
            
            Button("Weiter") {
                let newPet = Pet(
                    name: petName.isEmpty ? "Unbenannt" : petName,
                    emoji: selectedEmoji,
                    notificationsEnabled: true
                )
                
                currentPet = newPet
                isFirstLaunch = false
                
                if let data = try? JSONEncoder().encode(newPet) {
                    petData = data
                }
            }
            .padding()
            .buttonStyle(.bordered)
            .disabled(petName.isEmpty)
        }
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    @Binding var currentPet: Pet?
    @Binding var petData: Data
    
    var body: some View {
        TabView {
            PetView(currentPet: $currentPet)
                .tabItem {
                    Label("Haustier", systemImage: "pawprint")
                }
            
            SettingsView(currentPet: $currentPet, petData: $petData)
                .tabItem {
                    Label("Einstellungen", systemImage: "gearshape")
                }
        }
    }
}

// MARK: - Pet View
struct PetView: View {
    @Binding var currentPet: Pet?
    @AppStorage("lastHungerLevel") private var storedHungerLevel = 100
    @AppStorage("lastBackgroundDate") private var storedBackgroundDate: Date?
    @AppStorage("lastNotificationDate") private var lastNotificationDate: Date?
    
    @State private var hungerLevel = 100
    @State private var timer: Timer?
    
    @State private var isWiggling = false
    
    @State private var isFoodAnimating = false
    @State private var foodOffset: CGFloat = 0
    @State private var foodOpacity = 1.0
    
    @Environment(\.scenePhase) var scenePhase

    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                // Haustier-Info
                VStack {
                    Text(currentPet?.name ?? "Unbenannt")
                        .font(.largeTitle.bold())
                }
                
                // Hunger-Level Anzeige
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 10)
                        .frame(width: 200, height: 20)
                        .foregroundColor(.gray.opacity(0.5))
                    
                    RoundedRectangle(cornerRadius: 10)
                        .frame(width: CGFloat(hungerLevel) * 2, height: 20)
                        .foregroundColor(hungerLevel > 20 ? .green : .red)
                        .animation(.easeInOut, value: hungerLevel)
                }
                .padding(.bottom)
                
                // Katzen-Emoji mit Animation
                Text(currentPet?.emoji ?? "🐱")
                    .font(.system(size: 200))
                    .scaleEffect(hungerLevel <= 20 ? 0.9 : 1.0)
                    .animation(.spring(), value: hungerLevel)
                    .rotationEffect(.degrees(isWiggling ? 360 : 0))
                    .animation(
                    .easeInOut(duration: 0.3).repeatCount(1, autoreverses: true),
                        value: isWiggling
                    )
                    .onTapGesture(count: 2) {
                        triggerWiggle()
                    }
                    .padding(.top)
                
                // Futter-Button
                // Futter-Button mit Animation
                Button(action: {
                    feedCat()
                    if !isFoodAnimating {
                        triggerFoodAnimation()
                    }
                }) {
                    Text("🍖")
                        .font(.system(size: 100))
                        .padding()
                }
                .padding()
                .overlay(
                    Group {
                        if isFoodAnimating {
                            Text("🍖")
                                .font(.system(size: 80))
                                .offset(y: foodOffset)
                                .opacity(foodOpacity)
                                .transition(.identity)
                        }
                    }
                )
            
            }
            .onAppear(perform: setupApp)
            .onDisappear(perform: stopTimer)
            .onChange(of: scenePhase) { _, newPhase in
                handlePhaseChange(newPhase: newPhase)
            }
        }
    }
    
    private func triggerFoodAnimation() {
            isFoodAnimating = true
        withAnimation(.easeOut(duration: 0.7)) {
                foodOffset = -150
                foodOpacity = 0
            }
            
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                isFoodAnimating = false
                foodOffset = 0
                foodOpacity = 1.0
            }
        }
    
    private func triggerWiggle() {
        withAnimation {
            isWiggling.toggle()
            
            // Reset nach der Animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isWiggling = false
            }
        }
    }
    
    // MARK: - Benachrichtigungen
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { success, _ in
            if !success { print("Benachrichtigungen nicht erlaubt!") }
        }
    }
       
    private func scheduleNotification() {
        guard currentPet?.notificationsEnabled ?? false else { return }
        
        // Vor der Planung immer alte löschen
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
           
        // Nur planen wenn über 20
        guard hungerLevel > 20 else { return }
           
        let stepsNeeded = (hungerLevel - 20) / 10
        let seconds = stepsNeeded * 5
           
        guard seconds > 0 else { return }
           
        let content = UNMutableNotificationContent()
        content.title = "Hunger-Alarm!🚨"
        content.body = "\(currentPet?.name ?? "Dein Haustier") verhungert!🥺"
        content.sound = .default
           
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        let request = UNNotificationRequest(identifier: "hunger", content: content, trigger: trigger)
           
        UNUserNotificationCenter.current().add(request)
    }
    
    
    // (Die restlichen Methoden bleiben wie im Original, aber mit currentPet?.notificationsEnabled checks)
    private func sendImmediateNotification() {
        guard currentPet?.notificationsEnabled ?? false else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Hunger-Alarm!🚨"
        content.body = "\(currentPet?.name ?? "Dein Haustier") verhungert!🥺"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "immediateHunger",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - App-Lifecycle-Methoden
    private func setupApp() {
        UIApplication.shared.isIdleTimerDisabled = true
        startTimer()
        requestNotificationPermission()
    }

    private func stopTimer() {
        timer?.invalidate()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    private func handlePhaseChange(newPhase: ScenePhase) {
        if newPhase == .background {
            saveAppState()
        } else if newPhase == .active {
            restoreAppState()
        }
    }

    // MARK: - Hunger-Level-Logik
    private func feedCat() {
        hungerLevel = min(100, hungerLevel + 10)
        lastNotificationDate = nil
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1000, repeats: true) { _ in
            hungerLevel = max(0, hungerLevel - 5)
            
            // Nur prüfen wenn unter 20 UND letzte Benachrichtigung älter als 1 Minute
            if hungerLevel <= 20 && (lastNotificationDate == nil || Date().timeIntervalSince(lastNotificationDate!) > 60) {
                sendImmediateNotification()
                lastNotificationDate = Date()
            }
        }
    }
    
    // MARK: - Hintergrundverarbeitung
    private func saveAppState() {
        storedHungerLevel = hungerLevel
        storedBackgroundDate = Date()
        scheduleNotification()
    }
    
    private func restoreAppState() {
        guard let backgroundDate = storedBackgroundDate else { return }
        
        let elapsed = Date().timeIntervalSince(backgroundDate)
        let steps = Int(elapsed / 5.0)
        hungerLevel = max(0, storedHungerLevel - (steps * 10))
        
        storedBackgroundDate = nil
        scheduleNotification()
    }
}


// MARK: - Settings View
struct SettingsView: View {
    @Binding var currentPet: Pet?
    @Binding var petData: Data

    @State private var showingEmojiPicker = false
    @State private var temporaryPet: Pet?
    
    let availableEmojis = ["🐱", "🐶", "🐰", "🐻", "🐯", "🦊", "🐹", "🐮"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Haustier-Einstellungen")) {
                    TextField("Name", text: Binding(
                        get: { currentPet?.name ?? "" },
                        set: { currentPet?.name = $0 }
                    ))
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Speichern") {
                                UIApplication.shared.sendAction(
                                    #selector(UIResponder.resignFirstResponder),
                                    to: nil,
                                    from: nil,
                                    for: nil
                                )
                            }
                        }
                    }
                    
                    Button("Emoji ändern") {
                        temporaryPet = currentPet
                        showingEmojiPicker = true
                    }
                }
                
                Section(header: Text("Benachrichtigungen")) {
                    Toggle("Aktiviert", isOn: Binding(
                        get: { currentPet?.notificationsEnabled ?? true },
                        set: { currentPet?.notificationsEnabled = $0 }
                    ))
                }
            }
            .navigationTitle("Einstellungen")
            .sheet(isPresented: $showingEmojiPicker) {
                EmojiPickerView(selectedEmoji: Binding(
                    get: { temporaryPet?.emoji ?? "🐱" },
                    set: { temporaryPet?.emoji = $0 }
                ), onDismiss: {
                    currentPet = temporaryPet
                    showingEmojiPicker = false;
                    savePet()
                })
            }
        }
    }
    
    private func savePet() {
        guard let pet = currentPet else { return }
        if let data = try? JSONEncoder().encode(pet) {
            petData = data
        }
    }
}

// MARK: - Emoji Picker View
struct EmojiPickerView: View {
    @Binding var selectedEmoji: String
    var onDismiss: () -> Void
    
    let availableEmojis = ["🐱", "🐶", "🐰", "🐻", "🐯", "🦊", "🐹", "🐮"]
    
    var body: some View {
        VStack {
            Text("Wähle ein neues Emoji")
                .font(.title2)
                .padding()
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4)) {
                ForEach(availableEmojis, id: \.self) { emoji in
                    Text(emoji)
                        .font(.system(size: 50))
                        .padding()
                        .background(selectedEmoji == emoji ? .blue.opacity(0.3) : .clear)
                        .cornerRadius(10)
                        .onTapGesture {
                            selectedEmoji = emoji
                        }
                }
            }
            .padding()
            
            Button("Fertig") {
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
