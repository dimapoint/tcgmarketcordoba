import 'package:flutter/material.dart';

class OnboardingSlide {
  final IconData icon;
  final String title;
  final String body;

  /// Versión de onboarding en la que se agregó este slide.
  final int version;

  const OnboardingSlide({
    required this.icon,
    required this.title,
    required this.body,
    required this.version,
  });
}

const kOnboardingSlides = <OnboardingSlide>[
  OnboardingSlide(
    icon: Icons.storefront_outlined,
    title: 'Bienvenido a TCGMarket Córdoba',
    body: 'El marketplace P2P para comprar y vender cartas de Riftbound '
        'entre coleccionistas de Córdoba.',
    version: 1,
  ),
  OnboardingSlide(
    icon: Icons.add_circle_outline,
    title: 'Publicá tus cartas',
    body: 'Sacá una foto, elegí el estado y el precio: tu carta queda '
        'visible para toda la comunidad en minutos.',
    version: 1,
  ),
  OnboardingSlide(
    icon: Icons.forum_outlined,
    title: 'Contactá vendedores',
    body: 'Encontrá la carta que buscás y escribile directamente al '
        'vendedor para coordinar la compra.',
    version: 1,
  ),
  OnboardingSlide(
    icon: Icons.shield_outlined,
    title: 'Comprá con confianza',
    body: 'Revisá el estado de cada carta y el perfil del vendedor antes '
        'de coordinar el intercambio.',
    version: 1,
  ),
];

int get kOnboardingLatestVersion =>
    kOnboardingSlides.map((s) => s.version).reduce((a, b) => a > b ? a : b);
