# LessonClient


todo

onMove 학습
grid 학습


Project
├─ App
│  ├─ AppEntry.swift
│  └─ AppEnvironment.swift
│
├─ DesignSystem
│  ├─ Colors
│  │  └─ AppColor.swift
│  ├─ Fonts
│  │  └─ AppFont.swift
│  ├─ TextStyles
│  │  └─ TextStyle.swift
│  ├─ Modifiers
│  │  ├─ TitleTextStyle.swift
│  │  └─ CardModifier.swift
│  └─ Components
│     └─ PrimaryButton.swift
│
├─ Core
│  ├─ Network
│  │  ├─ APIClient.swift
│  │  ├─ Endpoint.swift
│  │  └─ NetworkError.swift
│  ├─ Persistence
│  │  └─ KeychainStorage.swift
│  ├─ Utils
│  │  └─ Logger.swift
│  └─ Extensions
│     └─ View+Common.swift
│
├─ Domain
│  ├─ Entities
│  │  └─ User.swift
│  ├─ Repositories
│  │  └─ UserRepository.swift   // protocol
│  └─ UseCases
│     └─ FetchUserUseCase.swift
│
├─ Data
│  ├─ DataSource
│  │  ├─ Remote
│  │  │  └─ UserRemoteDataSource.swift
│  │  └─ Local
│  │     └─ UserLocalDataSource.swift
│  │
│  ├─ Repository
│  │  └─ UserRepositoryImpl.swift
│  │
│  └─ DTO
│     └─ UserDTO.swift
│
├─ Features
│  ├─ Home
│  │  ├─ HomeView.swift
│  │  ├─ HomeViewModel.swift
│  │  └─ HomeCoordinator.swift
│  │
│  └─ Profile
│     ├─ ProfileView.swift
│     ├─ ProfileViewModel.swift
│     └─ ProfileCoordinator.swift
│
└─ Resources
   ├─ Assets.xcassets
   └─ Localizable.strings


