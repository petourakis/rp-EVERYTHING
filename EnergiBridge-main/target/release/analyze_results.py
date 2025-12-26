"""
SpotBugs Energy & Vulnerability Analysis
Analyzes the relationship between energy consumption and security findings
"""

import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from pathlib import Path
import numpy as np

def load_vulnerability_data(session_dir):
    """Load vulnerability summary CSV"""
    vuln_file = Path(session_dir) / "vulnerability_summary.csv"
    if not vuln_file.exists():
        print(f"Error: {vuln_file} not found")
        return None
    
    df = pd.read_csv(vuln_file)
    print(f"Loaded {len(df)} vulnerability records")
    return df

def load_energy_data(session_dir):
    """Load all energy CSV files and combine them"""
    energy_files = list(Path(session_dir).glob("run_*.csv"))
    
    if not energy_files:
        print(f"Error: No energy CSV files found in {session_dir}")
        return None
    
    dfs = []
    for file in energy_files:
        # Extract run number and config from filename
        # Format: run_X_config_Y.csv
        parts = file.stem.split('_')
        run_num = int(parts[1])
        config = parts[3]
        
        df = pd.read_csv(file)
        df['Run'] = run_num
        df['Config'] = config
        dfs.append(df)
    
    combined = pd.concat(dfs, ignore_index=True)
    print(f"Loaded {len(dfs)} energy measurement files")
    return combined

def merge_data(vuln_df, energy_df):
    """Merge vulnerability and energy data"""
    # Calculate total energy per run
    energy_summary = energy_df.groupby(['Run', 'Config']).agg({
        'package_energy': 'sum',
        'dram_energy': 'sum',
        'timestamp': lambda x: (x.max() - x.min()) / 1000  # Duration in seconds
    }).reset_index()
    
    energy_summary.columns = ['Run', 'Config', 'TotalPackageEnergy_J', 'TotalDRAMEnergy_J', 'Duration_s']
    energy_summary['TotalEnergy_J'] = energy_summary['TotalPackageEnergy_J'] + energy_summary['TotalDRAMEnergy_J']
    
    # Merge with vulnerability data
    merged = pd.merge(vuln_df, energy_summary, on=['Run', 'Config'], how='inner')
    
    print(f"Merged dataset: {len(merged)} records")
    return merged

def analyze_config_comparison(df):
    """Compare configurations"""
    print("\n" + "="*60)
    print("CONFIGURATION COMPARISON")
    print("="*60)
    
    # Group by config
    config_stats = df[df['Status'] == 'SUCCESS'].groupby('Config').agg({
        'BugCount': ['mean', 'std', 'min', 'max'],
        'TotalEnergy_J': ['mean', 'std'],
        'Duration_s': ['mean', 'std']
    }).round(2)
    
    print("\nBy Configuration:")
    print(config_stats)
    
    # Energy efficiency: Bugs found per Joule
    config_efficiency = df[df['Status'] == 'SUCCESS'].groupby('Config').apply(
        lambda x: pd.Series({
            'AvgBugs': x['BugCount'].mean(),
            'AvgEnergy_J': x['TotalEnergy_J'].mean(),
            'BugsPerJoule': x['BugCount'].sum() / x['TotalEnergy_J'].sum(),
            'JoulesPerBug': x['TotalEnergy_J'].sum() / max(x['BugCount'].sum(), 1)
        })
    ).round(4)
    
    print("\nEnergy Efficiency:")
    print(config_efficiency)
    
    return config_stats, config_efficiency

def analyze_project_comparison(df):
    """Compare projects"""
    print("\n" + "="*60)
    print("PROJECT COMPARISON")
    print("="*60)
    
    project_stats = df[df['Status'] == 'SUCCESS'].groupby('Project').agg({
        'BugCount': ['mean', 'sum', 'max'],
        'TotalEnergy_J': ['mean', 'sum'],
        'Duration_s': ['mean']
    }).round(2)
    
    print("\nBy Project:")
    print(project_stats)
    
    return project_stats

def analyze_effort_vs_findings(df):
    """Analyze relationship between effort and findings"""
    print("\n" + "="*60)
    print("EFFORT vs FINDINGS ANALYSIS")
    print("="*60)
    
    # Config B (max effort) vs Config A (default)
    config_a = df[(df['Config'] == 'A') & (df['Status'] == 'SUCCESS')]
    config_b = df[(df['Config'] == 'B') & (df['Status'] == 'SUCCESS')]
    
    if len(config_a) > 0 and len(config_b) > 0:
        avg_bugs_a = config_a['BugCount'].mean()
        avg_bugs_b = config_b['BugCount'].mean()
        avg_energy_a = config_a['TotalEnergy_J'].mean()
        avg_energy_b = config_b['TotalEnergy_J'].mean()
        
        print(f"\nConfig A (Default):")
        print(f"  Average bugs found: {avg_bugs_a:.2f}")
        print(f"  Average energy: {avg_energy_a:.2f} J")
        
        print(f"\nConfig B (Max Effort):")
        print(f"  Average bugs found: {avg_bugs_b:.2f}")
        print(f"  Average energy: {avg_energy_b:.2f} J")
        
        print(f"\nDifference:")
        print(f"  Additional bugs found: {avg_bugs_b - avg_bugs_a:.2f} ({((avg_bugs_b/avg_bugs_a - 1)*100):.1f}%)")
        print(f"  Additional energy used: {avg_energy_b - avg_energy_a:.2f} J ({((avg_energy_b/avg_energy_a - 1)*100):.1f}%)")
        print(f"  Energy cost per additional bug: {(avg_energy_b - avg_energy_a) / max(avg_bugs_b - avg_bugs_a, 1):.2f} J/bug")

def create_visualizations(df, output_dir):
    """Create visualization plots"""
    print("\n" + "="*60)
    print("CREATING VISUALIZATIONS")
    print("="*60)
    
    output_dir = Path(output_dir)
    output_dir.mkdir(exist_ok=True)
    
    # Set style
    sns.set_style("whitegrid")
    plt.rcParams['figure.figsize'] = (12, 8)
    
    # Filter successful runs
    df_success = df[df['Status'] == 'SUCCESS'].copy()
    
    # 1. Energy vs Bugs by Configuration
    fig, ax = plt.subplots(1, 1, figsize=(10, 6))
    for config in ['A', 'B', 'C']:
        data = df_success[df_success['Config'] == config]
        ax.scatter(data['TotalEnergy_J'], data['BugCount'], 
                  label=f'Config {config}', alpha=0.6, s=100)
    
    ax.set_xlabel('Total Energy (Joules)', fontsize=12)
    ax.set_ylabel('Bugs Found', fontsize=12)
    ax.set_title('Energy Consumption vs Bugs Found by Configuration', fontsize=14)
    ax.legend()
    ax.grid(True, alpha=0.3)
    plt.tight_layout()
    plt.savefig(output_dir / 'energy_vs_bugs_by_config.png', dpi=300)
    print(f"  Saved: energy_vs_bugs_by_config.png")
    plt.close()
    
    # 2. Box plot: Bugs by Configuration
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 6))
    
    df_success.boxplot(column='BugCount', by='Config', ax=ax1)
    ax1.set_xlabel('Configuration', fontsize=12)
    ax1.set_ylabel('Bugs Found', fontsize=12)
    ax1.set_title('Bug Count Distribution by Configuration', fontsize=12)
    plt.sca(ax1)
    plt.xticks([1, 2, 3], ['A (Default)', 'B (Max Effort)', 'C (Low Threshold)'])
    
    df_success.boxplot(column='TotalEnergy_J', by='Config', ax=ax2)
    ax2.set_xlabel('Configuration', fontsize=12)
    ax2.set_ylabel('Total Energy (J)', fontsize=12)
    ax2.set_title('Energy Distribution by Configuration', fontsize=12)
    plt.sca(ax2)
    plt.xticks([1, 2, 3], ['A (Default)', 'B (Max Effort)', 'C (Low Threshold)'])
    
    plt.tight_layout()
    plt.savefig(output_dir / 'distribution_comparison.png', dpi=300)
    print(f"  Saved: distribution_comparison.png")
    plt.close()
    
    # 3. Project comparison
    project_summary = df_success.groupby('Project').agg({
        'BugCount': 'mean',
        'TotalEnergy_J': 'mean'
    }).reset_index()
    
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(12, 10))
    
    ax1.barh(project_summary['Project'], project_summary['BugCount'])
    ax1.set_xlabel('Average Bugs Found', fontsize=12)
    ax1.set_title('Average Bugs Found by Project', fontsize=14)
    ax1.grid(True, alpha=0.3, axis='x')
    
    ax2.barh(project_summary['Project'], project_summary['TotalEnergy_J'])
    ax2.set_xlabel('Average Energy (J)', fontsize=12)
    ax2.set_title('Average Energy Consumption by Project', fontsize=14)
    ax2.grid(True, alpha=0.3, axis='x')
    
    plt.tight_layout()
    plt.savefig(output_dir / 'project_comparison.png', dpi=300)
    print(f"  Saved: project_comparison.png")
    plt.close()
    
    # 4. Efficiency Analysis
    fig, ax = plt.subplots(figsize=(10, 6))
    
    for config in ['A', 'B', 'C']:
        data = df_success[df_success['Config'] == config]
        if len(data) > 0:
            efficiency = data['BugCount'] / data['TotalEnergy_J'] * 1000  # Bugs per kJ
            ax.scatter([config] * len(efficiency), efficiency, 
                      alpha=0.6, s=100, label=f'Config {config}')
    
    ax.set_xlabel('Configuration', fontsize=12)
    ax.set_ylabel('Bugs Found per kJ', fontsize=12)
    ax.set_title('Energy Efficiency: Bugs Found per Kilojoule', fontsize=14)
    ax.grid(True, alpha=0.3, axis='y')
    plt.tight_layout()
    plt.savefig(output_dir / 'energy_efficiency.png', dpi=300)
    print(f"  Saved: energy_efficiency.png")
    plt.close()
    
    print(f"\nAll plots saved to: {output_dir}")

def generate_summary_report(df, output_dir):
    """Generate text summary report"""
    output_dir = Path(output_dir)
    report_file = output_dir / "analysis_summary.txt"
    
    with open(report_file, 'w') as f:
        f.write("="*70 + "\n")
        f.write("SPOTBUGS ENERGY & VULNERABILITY ANALYSIS REPORT\n")
        f.write("="*70 + "\n\n")
        
        # Overall statistics
        f.write("OVERALL STATISTICS\n")
        f.write("-"*70 + "\n")
        f.write(f"Total runs: {len(df)}\n")
        f.write(f"Successful runs: {len(df[df['Status'] == 'SUCCESS'])}\n")
        f.write(f"Failed runs: {len(df[df['Status'] == 'FAILED'])}\n")
        f.write(f"Projects analyzed: {df['Project'].nunique()}\n")
        f.write(f"Build tools: {', '.join(df['BuildTool'].unique())}\n\n")
        
        # Success rate by config
        success_by_config = df.groupby('Config')['Status'].apply(
            lambda x: (x == 'SUCCESS').sum() / len(x) * 100
        )
        f.write("Success rate by configuration:\n")
        for config, rate in success_by_config.items():
            f.write(f"  Config {config}: {rate:.1f}%\n")
        f.write("\n")
        
        # Key findings
        df_success = df[df['Status'] == 'SUCCESS']
        
        f.write("KEY FINDINGS\n")
        f.write("-"*70 + "\n")
        f.write(f"Total bugs found: {df_success['BugCount'].sum():.0f}\n")
        f.write(f"Average bugs per run: {df_success['BugCount'].mean():.2f}\n")
        f.write(f"Total energy consumed: {df_success['TotalEnergy_J'].sum():.2f} J\n")
        f.write(f"Average energy per run: {df_success['TotalEnergy_J'].mean():.2f} J\n")
        f.write(f"Overall efficiency: {df_success['BugCount'].sum() / df_success['TotalEnergy_J'].sum() * 1000:.4f} bugs/kJ\n")
        f.write("\n")
        
        # Config comparison
        f.write("CONFIGURATION COMPARISON\n")
        f.write("-"*70 + "\n")
        for config in ['A', 'B', 'C']:
            config_data = df_success[df_success['Config'] == config]
            if len(config_data) > 0:
                f.write(f"\nConfig {config}:\n")
                f.write(f"  Runs: {len(config_data)}\n")
                f.write(f"  Avg bugs: {config_data['BugCount'].mean():.2f}\n")
                f.write(f"  Avg energy: {config_data['TotalEnergy_J'].mean():.2f} J\n")
                f.write(f"  Efficiency: {config_data['BugCount'].sum() / config_data['TotalEnergy_J'].sum() * 1000:.4f} bugs/kJ\n")
    
    print(f"\nSummary report saved to: {report_file}")

def main():
    """Main analysis function"""
    print("="*70)
    print("SPOTBUGS ENERGY & VULNERABILITY ANALYSIS")
    print("="*70)
    
    # Get session directory from user
    session_dir = input("\nEnter path to results session directory: ").strip('"')
    
    if not Path(session_dir).exists():
        print(f"Error: Directory not found: {session_dir}")
        return
    
    # Load data
    vuln_df = load_vulnerability_data(session_dir)
    if vuln_df is None:
        return
    
    energy_df = load_energy_data(session_dir)
    if energy_df is None:
        return
    
    # Merge data
    merged_df = merge_data(vuln_df, energy_df)
    
    # Save merged dataset
    output_file = Path(session_dir) / "merged_analysis_data.csv"
    merged_df.to_csv(output_file, index=False)
    print(f"\nMerged data saved to: {output_file}")
    
    # Perform analyses
    analyze_config_comparison(merged_df)
    analyze_project_comparison(merged_df)
    analyze_effort_vs_findings(merged_df)
    
    # Create visualizations
    create_visualizations(merged_df, session_dir)
    
    # Generate summary report
    generate_summary_report(merged_df, session_dir)
    
    print("\n" + "="*70)
    print("ANALYSIS COMPLETE!")
    print("="*70)
    print(f"\nResults saved to: {session_dir}")
    print("\nGenerated files:")
    print("  - merged_analysis_data.csv (combined data)")
    print("  - analysis_summary.txt (text report)")
    print("  - energy_vs_bugs_by_config.png")
    print("  - distribution_comparison.png")
    print("  - project_comparison.png")
    print("  - energy_efficiency.png")

if __name__ == "__main__":
    main()
