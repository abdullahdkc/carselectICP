import Result "mo:base/Result";
import HashMap "mo:base/HashMap";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Array "mo:base/Array";
import Principal "mo:base/Principal";
import Float "mo:base/Float";

actor PersonalizedVehicleSelection {
    // Araç türleri
    type VehicleType = {
        #Sedan;
        #SUV;
        #Hatchback;
        #Coupe;
        #Pickup;
        #Minivan;
    };

    // Kullanım amaçları
    type UsagePurpose = {
        #DailyCommute;
        #FamilyTrips;
        #OffRoad;
        #BusinessUse;
        #SportsDriving;
        #Camping;
    };

    // Yakıt türleri
    type FuelType = {
        #Gasoline;
        #Diesel;
        #Electric;
        #Hybrid;
    };

    // Araç bilgileri yapısı
    type Vehicle = {
        id: Text;
        make: Text;
        model: Text;
        year: Nat;
        vehicleType: VehicleType;
        fuelType: FuelType;
        priceRange: (Nat, Nat);
        horsePower: Nat;
        fuelEfficiency: Float;
        suitableFor: [UsagePurpose];
        imageUrl: ?Text;
    };

    // Kullanıcı tercihleri yapısı
    type UserPreferences = {
        budget: (Nat, Nat);
        preferredVehicleTypes: [VehicleType];
        primaryUsagePurpose: UsagePurpose;
        fuelPreference: ?FuelType;
        minimumHorsePower: Nat;
        requiredFuelEfficiency: ?Float;
    };

    // Eşleşme sonucu yapısı
    type VehicleMatch = {
        vehicle: Vehicle;
        matchScore: Float;
    };

    // Araç ve kullanıcı tercihi kayıtları
    private var vehicles = HashMap.HashMap<Text, Vehicle>(10, Text.equal, Text.hash);
    private var userPreferences = HashMap.HashMap<Principal, UserPreferences>(10, Principal.equal, Principal.hash);

    // Yeni araç ekleme
    public func addVehicle(vehicle: Vehicle) : async Result.Result<(), Text> {
        switch (vehicles.get(vehicle.id)) {
            case (null) {
                vehicles.put(vehicle.id, vehicle);
                #ok();
            };
            case (_) {
                #err("Bu ID'ye sahip bir araç zaten mevcut");
            };
        };
    }

    // Kullanıcı tercihlerini kaydetme
    public shared(msg) func saveUserPreferences(preferences: UserPreferences) : async Result.Result<(), Text> {
        userPreferences.put(msg.caller, preferences);
        #ok();
    }

    // Araç eşleştirme algoritması
    private func calculateMatchScore(vehicle: Vehicle, preferences: UserPreferences) : Float {
        var score : Float = 0.0;

        // Bütçe uygunluğu
        if (vehicle.priceRange.0 >= preferences.budget.0 and vehicle.priceRange.1 <= preferences.budget.1) {
            score += 25.0;
        };

        // Araç türü uygunluğu
        if (Array.find(preferences.preferredVehicleTypes, func(x : VehicleType) : Bool { x == vehicle.vehicleType }) != null) {
            score += 20.0;
        };

        // Kullanım amacı uygunluğu
        if (Array.find(vehicle.suitableFor, func(x : UsagePurpose) : Bool { x == preferences.primaryUsagePurpose }) != null) {
            score += 20.0;
        };

        // Yakıt türü uygunluğu
        switch (preferences.fuelPreference) {
            case (?pref) {
                if (pref == vehicle.fuelType) {
                    score += 15.0;
                };
            };
            case (null) {};
        };

        // Beygir gücü kontrolü
        if (vehicle.horsePower >= preferences.minimumHorsePower) {
            score += 10.0;
        };

        // Yakıt verimliliği kontrolü
        switch (preferences.requiredFuelEfficiency) {
            case (?reqEfficiency) {
                if (vehicle.fuelEfficiency >= reqEfficiency) {
                    score += 10.0;
                };
            };
            case (null) {};
        };

        return score;
    }

    // Kişiye özel araç önerisi
    public shared(msg) func getPersonalizedVehicleRecommendations() : async Result.Result<[VehicleMatch], Text> {
        switch (userPreferences.get(msg.caller)) {
            case (?preferences) {
                let matches = Array.map(
                    Iter.toArray(vehicles.vals()),
                    func(vehicle: Vehicle) : VehicleMatch {
                        {
                            vehicle = vehicle;
                            matchScore = calculateMatchScore(vehicle, preferences)
                        }
                    }
                );

                let sortedMatches = Array.sort(
                    matches, 
                    func(a: VehicleMatch, b: VehicleMatch) : Order.Order {
                        if (a.matchScore > b.matchScore) { #greater }
                        else if (a.matchScore < b.matchScore) { #less }
                        else { #equal }
                    }
                );

                #ok(Array.slice(sortedMatches, 0, 5)); // En iyi 5 eşleşmeyi döndür
            };
            case (null) {
                #err("Kullanıcı tercihleri bulunamadı");
            };
        };
    }

    // Tüm araçları listeleme
    public query func listAllVehicles() : async [Vehicle] {
        Iter.toArray(vehicles.vals())
    }

    // Belirli bir türdeki araçları listeleme
    public query func listVehiclesByType(vehicleType: VehicleType) : async [Vehicle] {
        Array.filter(
            Iter.toArray(vehicles.vals()),
            func(vehicle: Vehicle) : Bool { vehicle.vehicleType == vehicleType }
        );
    }
}
