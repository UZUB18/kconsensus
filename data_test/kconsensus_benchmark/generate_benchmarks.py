#!/usr/bin/env python3
"""Regenerate synthetic, deterministic datasets for an R cluster-count package.

Requires numpy and pandas. Data files contain ONLY features; truth is separate.
This script creates a designed benchmark, not statistically certified best-K labels.
"""
from pathlib import Path
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parent
SEED = 20261105
manifest = []


def draw_groups(rng, specs):
    """specs: list of (count, mean array, scalar sigma or covariance matrix)"""
    pieces, labels = [], []
    for i, (n, mean, spread) in enumerate(specs, 1):
        mean = np.asarray(mean, dtype=float)
        if np.ndim(spread) == 0:
            sample = rng.normal(loc=mean, scale=float(spread), size=(n, len(mean)))
        else:
            sample = rng.multivariate_normal(mean, np.asarray(spread), size=n)
        pieces.append(sample)
        labels.extend([i] * n)
    return np.vstack(pieces), np.asarray(labels, dtype=int)


def register(name, x, labels, groups, property, expectation, seed, valid=True):
    df = pd.DataFrame(x, columns=[f"x{i:02d}" for i in range(1, x.shape[1] + 1)])
    if labels is not None:
        assert len(labels) == len(df)
    if valid:
        out = ROOT / 'data' / f'{name}.csv'
        truth = ROOT / 'truth' / f'{name}_labels.csv' if labels is not None else None
        df.to_csv(out, index=False, float_format='%.8f')
        if labels is not None:
            pd.DataFrame({'row_index': np.arange(1, len(df) + 1),
                          'generating_group': labels}).to_csv(truth, index=False)
    else:
        out = ROOT / 'invalid' / f'{name}.csv'
        truth = None
        df.to_csv(out, index=False, float_format='%.8f')
    manifest.append({
        'scenario': name,
        'csv_path': out.relative_to(ROOT).as_posix(),
        'labels_path': truth.relative_to(ROOT).as_posix() if truth else '',
        'n_rows': len(df), 'n_features': df.shape[1],
        'generating_groups': groups,
        'valid_input': valid,
        'seed': seed,
        'scenario_design': property,
        'expected_behavior_to_inspect': expectation,
    })


def make(name, fn, groups, property, expectation, valid=True):
    seed = SEED + len(manifest) * 97
    rng = np.random.default_rng(seed)
    x, labels = fn(rng)
    if valid:
        p = rng.permutation(len(x))
        x, labels = x[p], labels[p] if labels is not None else None
    register(name, x, labels, groups, property, expectation, seed, valid)


def main_stress(r):
    x, y = draw_groups(r, [
        (265, [-5.2, -1.0], 1.0),
        (220, [0.2, 5.3], 1.1),
        (190, [5.5, -0.7], 1.15),
        (45, [5.5, 1.4], 0.55),
    ])
    # Outliers are known contamination, not a fifth generated cluster.
    outliers = r.uniform(low=[-10, -7], high=[10, 10], size=(30, 2))
    return np.vstack([x, outliers]), np.concatenate([y, np.full(30, -1)])


def clean_3(r):
    return draw_groups(r, [(180, [-7., -2.], .65), (180, [0., 7.], .65), (180, [7., -2.], .65)])


def clean_5(r):
    theta = np.linspace(0, 2 * np.pi, 5, endpoint=False)
    centers = [(8 * np.cos(a), 8 * np.sin(a)) for a in theta]
    return draw_groups(r, [(120, c, .55) for c in centers])


def overlapping_3(r):
    return draw_groups(r, [(200, [-2., 0.], 1.7), (200, [0., 1.5], 1.7), (200, [2., 0.], 1.7)])


def unbalanced_4(r):
    return draw_groups(r, [(420, [-6., -5.], .95), (105, [6., -5.], .95),
                           (34, [-6., 6.], .95), (11, [6., 6.], .95)])


def anisotropic_3(r):
    return draw_groups(r, [(200, [-5., 0.], [[6., 4.], [4., 3.4]]),
                           (200, [0., 5.], [[4., -3.], [-3., 3.]]),
                           (200, [6., 0.], [[4., 2.2], [2.2, 2.0]])])


def variable_density_3(r):
    return draw_groups(r, [(200, [-6., 0.], .25), (200, [0., 6.], 1.0), (200, [6., 0.], 2.5)])


def rings_2(r):
    theta_a = r.uniform(0, 2 * np.pi, 300)
    theta_b = r.uniform(0, 2 * np.pi, 300)
    ra = 2 + r.normal(0, .15, 300)
    rb = 6 + r.normal(0, .18, 300)
    x = np.vstack([np.column_stack([ra * np.cos(theta_a), ra * np.sin(theta_a)]),
                   np.column_stack([rb * np.cos(theta_b), rb * np.sin(theta_b)])])
    return x, np.r_[np.ones(300, int), np.full(300, 2)]


def moons_2(r):
    theta1 = r.uniform(0, np.pi, 300)
    theta2 = r.uniform(0, np.pi, 300)
    a = np.column_stack([np.cos(theta1), np.sin(theta1)])
    b = np.column_stack([1 - np.cos(theta2), .5 - np.sin(theta2)])
    x = np.vstack([a, b]) * 5 + r.normal(0, .45, (600, 2))
    return x, np.r_[np.ones(300, int), np.full(300, 2)]


def high_dim_3(r):
    x, y = draw_groups(r, [(180, [-4, 0, 0], 1.0),
                           (180, [0, 4, 0], 1.0),
                           (180, [4, 0, 0], 1.0)])
    return np.column_stack([x, r.normal(0, 1.8, size=(len(x), 27))]), y


def uniform_noise(r):
    return r.uniform(-6, 6, size=(600, 2)), None


def single_gaussian(r):
    return r.multivariate_normal([0, 0], [[4, 1.2], [1.2, 2]], 550), None


def outliers_3(r):
    x, y = draw_groups(r, [(180, [-6, -1], .8), (180, [0, 6], .8), (180, [6, -1], .8)])
    z = r.uniform(-14, 14, size=(45, 2))
    return np.vstack([x, z]), np.r_[y, np.full(45, -1)]


def duplicated_3(r):
    x, y = draw_groups(r, [(115, [-6, 0], .7), (115, [0, 6], .7), (115, [6, 0], .7)])
    idx = r.choice(len(x), 60, replace=True)
    return np.vstack([x, x[idx]]), np.r_[y, y[idx]]


def many_12(r):
    theta = np.linspace(0, 2 * np.pi, 12, endpoint=False)
    centers = [(11 * np.cos(a), 11 * np.sin(a)) for a in theta]
    return draw_groups(r, [(65, c, .35) for c in centers])


def near_split_4(r):
    return draw_groups(r, [(200, [-6, 0], 1.1), (200, [0, 6], 1.1),
                           (150, [6, 0], 1.1), (50, [6, 1.45], .7)])


def constant_feature_3(r):
    x, y = clean_3(r)
    return np.column_stack([x, np.zeros(len(x))]), y


def tiny_3(r):
    return draw_groups(r, [(6, [-5, 0], .2), (6, [0, 5], .2), (6, [5, 0], .2)])


def identical(r):
    return np.tile([1., 1.], (80, 1)), None


def missing(r):
    x, y = clean_3(r)
    x[7, 0] = np.nan
    x[20, 1] = np.nan
    return x, y


def infinity(r):
    x, y = clean_3(r)
    x[5, 0] = np.inf
    return x, y


def insufficient_distinct(r):
    x = np.tile([[0., 0.], [1., 1.]], (50, 1))
    return x, None


def non_numeric(r):
    x, y = clean_3(r)
    # Non-numeric invalid file is prepared separately to ensure a genuine string column.
    return x, y


make('cluster_stress_test', main_stress, '4 + outliers',
     '3 large groups, a nearby small fourth group, and scattered outliers',
     'Methods may prefer 3 versus 4 or split offliers; do not assume generating K is optimal for K-means')
make('clear_3', clean_3, '3', 'Three balanced, well-separated Gaussian groups',
     'Sanity check: many K-means criteria should favor 3')
make('clear_5', clean_5, '5', 'Five well-separated Gaussian groups',
     'Sanity check: many K-means criteria should favor 5')
make('overlap_3', overlapping_3, '3', 'Three heavily overlapping Gaussian groups',
     'Lower silhouette values; ambiguous preferred K likely')
make('unbalanced_4', unbalanced_4, '4', 'Strongly unequal group sizes, including 11-point group',
     'Check if small groups are ignored or merged')
make('anisotropic_3', anisotropic_3, '3', 'Three elongated, tilted Gaussian groups',
     'K-means spherical-cluster bias; may over-split')
make('variable_density_3', variable_density_3, '3', 'Three groups with very different variance',
     'Check density and variance bias')
make('concentric_rings_2', rings_2, '2', 'Two concentric non-convex rings',
     'K-means partitions will not recover ring memberships well')
make('two_moons_2', moons_2, '2', 'Two interlocking non-convex crescent shapes',
     'K-means may choose 2 but fail to recover the true shapes')
make('high_dim_noise_3', high_dim_3, '3', 'Three signal groups in first 3 of 30 columns; remaining 27 noisy',
     'Evaluate signal dilution, high-dimensional distances and runtime')
make('uniform_no_clusters', uniform_noise, 'none', 'Uniform 2D point cloud with no discrete generating groups',
     'Package should not interpret a numerical winner as proof of true groups')
make('single_gaussian', single_gaussian, '1 / unimodal', 'One correlated Gaussian distribution',
     'K=1 is plausible; do not force a meaningful split')
make('outliers_3', outliers_3, '3 + outliers', 'Three clean groups plus 45 uniformly scattered outliers',
     'Check how outliers influence votes and inertia')
make('duplicate_points_3', duplicated_3, '3', 'Three groups plus 60 exact repeated observations',
     'Handle duplicate observations; avoid invalid cluster indices')
make('many_12', many_12, '12', 'Twelve well-separated groups in a ring',
     'K=2:10 excludes generating K; detect upper boundary selection')
make('close_split_4', near_split_4, '4', 'Four generating groups, two with close centers',
     'K=3 vs K=4 disagreement is plausible')
make('constant_feature_3', constant_feature_3, '3', 'Three groups with a constant third numeric column',
     'Valid numeric input; do not silently scale a zero-variance column')
make('tiny_3', tiny_3, '3', 'Only eighteen observations in three groups',
     'Stress small-n indices, singleton partitions and K boundaries')
make('invalid_all_identical', identical, 'none', 'Only one distinct data point repeated 80 times',
     'Reject K>=2 with a clear message', valid=False)
make('invalid_missing', missing, '3', 'Includes missing numeric values',
     'Reject input with NA', valid=False)
make('invalid_infinite', infinity, '3', 'Includes an infinite numeric value',
     'Reject non-finite input', valid=False)
make('invalid_few_distinct', insufficient_distinct, '2 distinct points',
     'Only 2 distinct rows despite 100 observations',
     'Reject requests for more than 2 nonempty clusters', valid=False)

# Include genuine non-numeric CSV with all feature columns, one of them character.
xx, _ = non_numeric(np.random.default_rng(SEED + 10001))
nonnum = pd.DataFrame(xx, columns=['x01', 'x02'])
nonnum['category'] = np.where(nonnum['x01'] > 0, 'east', 'west')
path = ROOT / 'invalid' / 'invalid_nonnumeric.csv'
nonnum.to_csv(path, index=False, float_format='%.8f')
manifest.append({
    'scenario': 'invalid_nonnumeric', 'csv_path': 'invalid/invalid_nonnumeric.csv',
    'labels_path': '', 'n_rows': len(nonnum), 'n_features': len(nonnum.columns),
    'generating_groups': '3', 'valid_input': False, 'seed': SEED + 10001,
    'scenario_design': 'Character-valued category column alongside numeric features',
    'expected_behavior_to_inspect': 'Reject categorical input rather than silently encoding it'
})

pd.DataFrame(manifest).to_csv(ROOT / 'manifest.csv', index=False)
print('Generated', len(manifest), 'scenarios')
for row in manifest:
    print(f"{row['scenario']:<27} {row['n_rows']:>4} rows {row['n_features']:>2} cols | valid={row['valid_input']}")
