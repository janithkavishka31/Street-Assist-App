import SwiftUI

struct HelpZonesView: View {
    var onBack: (() -> Void)?

    @State private var isShowingJoinZoneScannerSheet = false
    @State private var isShowingJoinZoneManualSheet = false
    @State private var isShowingCreateZoneSheet = false

    var body: some View {
        VStack(spacing: 0) {
            StreetAssistNavBar(
                title: "Help Zones",
                leadingStyle: .back,
                trailingStyle: .avatar,
                onBackTap: { onBack?() }
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("My Help-Zones.")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(.top, 10)

                    HStack(spacing: 14) {
                        actionCard(
                            title: "Join Zone",
                            icon: "qrcode.viewfinder",
                            isPrimary: true,
                            onTap: { isShowingJoinZoneScannerSheet = true }
                        )

                        actionCard(
                            title: "Create Zone",
                            icon: "checkmark.shield",
                            isPrimary: false,
                            onTap: { isShowingCreateZoneSheet = true }
                        )
                    }

                    HStack(alignment: .center, spacing: 10) {
                        Text("My Zones")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)

                        Text("2")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.06))
                            .clipShape(Capsule())

                        Spacer()
                    }

                    VStack(spacing: 14) {
                        zoneRow(
                            icon: "graduationcap.fill",
                            iconBackground: AppTheme.categoryBlueBackground,
                            iconForeground: AppTheme.primaryBlue,
                            title: "Campus",
                            subtitle: "1,240 members • Active now",
                            trusted: true
                        )

                        zoneRow(
                            icon: "building.2.fill",
                            iconBackground: Color.black.opacity(0.06),
                            iconForeground: AppTheme.textSecondary,
                            title: "Hostel Block B",
                            subtitle: "450 members • 12 requests",
                            trusted: true
                        )
                    }

                    HStack {
                        Text("Zone-Only Requests")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)

                        Spacer()

                        Button {
                            // wired later
                        } label: {
                            Text("View All")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(AppTheme.primaryBlue)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 6)

                    zoneRequestCard
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }
        }
        .background(AppTheme.screenBackground)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isShowingJoinZoneScannerSheet) {
            if #available(iOS 16.4, *) {
                JoinHelpZoneScannerSheetView(
                    isPresented: $isShowingJoinZoneScannerSheet,
                    onManualEntry: { isShowingJoinZoneManualSheet = true }
                )
                .presentationDetents([.fraction(0.78)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
            } else if #available(iOS 16.0, *) {
                JoinHelpZoneScannerSheetView(
                    isPresented: $isShowingJoinZoneScannerSheet,
                    onManualEntry: { isShowingJoinZoneManualSheet = true }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            } else {
                JoinHelpZoneScannerSheetView(
                    isPresented: $isShowingJoinZoneScannerSheet,
                    onManualEntry: { isShowingJoinZoneManualSheet = true }
                )
            }
        }
        .sheet(isPresented: $isShowingJoinZoneManualSheet) {
            if #available(iOS 16.4, *) {
                JoinHelpZoneManualCodeSheetView(isPresented: $isShowingJoinZoneManualSheet)
                    .presentationDetents([.fraction(0.52)])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(28)
            } else if #available(iOS 16.0, *) {
                JoinHelpZoneManualCodeSheetView(isPresented: $isShowingJoinZoneManualSheet)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            } else {
                JoinHelpZoneManualCodeSheetView(isPresented: $isShowingJoinZoneManualSheet)
            }
        }
        .sheet(isPresented: $isShowingCreateZoneSheet) {
            if #available(iOS 16.4, *) {
                CreateHelpZoneSheetView(isPresented: $isShowingCreateZoneSheet)
                    .presentationDetents([.fraction(0.90)])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(28)
            } else if #available(iOS 16.0, *) {
                CreateHelpZoneSheetView(isPresented: $isShowingCreateZoneSheet)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            } else {
                CreateHelpZoneSheetView(isPresented: $isShowingCreateZoneSheet)
            }
        }
    }

    private func actionCard(title: String, icon: String, isPrimary: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isPrimary ? Color.white.opacity(0.18) : AppTheme.categoryBlueBackground)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(isPrimary ? .white : AppTheme.primaryBlue)
                    )

                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(isPrimary ? .white : AppTheme.textPrimary)

                Spacer(minLength: 0)
            }
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(
                Group {
                    if isPrimary {
                        LinearGradient(
                            colors: [AppTheme.primaryBlueDark, AppTheme.primaryBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        AppTheme.cardBackground
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
            .shadow(color: AppTheme.shadow, radius: 18, x: 0, y: 12)
        }
        .buttonStyle(.plain)
    }

    private func zoneRow(
        icon: String,
        iconBackground: Color,
        iconForeground: Color,
        title: String,
        subtitle: String,
        trusted: Bool
    ) -> some View {
        Button {
            // wired later
        } label: {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(iconBackground)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(iconForeground)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)

                        if trusted {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 12, weight: .bold))
                                Text("Trusted")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundStyle(AppTheme.primaryBlue)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AppTheme.categoryBlueBackground)
                            .clipShape(Capsule())
                        }
                    }

                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(16)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
            .shadow(color: AppTheme.shadow, radius: 14, x: 0, y: 10)
        }
        .buttonStyle(.plain)
    }

    private var zoneRequestCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.black.opacity(0.08))
                    .frame(width: 46, height: 46)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(AppTheme.textSecondary)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Raveen")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text("• 5m ago")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("Campus")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.9))
                .clipShape(Capsule())
            }

            Text("Need a help to fix my bicycle chain.")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            Button {
                // wired later
            } label: {
                Text("Help Sarah")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.primaryBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(Color.black.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        HelpZonesView(onBack: {})
            .toolbar(.hidden, for: .navigationBar)
    }
}
