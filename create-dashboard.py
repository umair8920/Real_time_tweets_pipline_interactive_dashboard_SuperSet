#!/usr/bin/env python3
"""
Twitter Personality Analysis Dashboard Creator
Automatically creates professional charts and dashboard in Superset
"""

import requests
import json
import time
import sys
from datetime import datetime

class SupersetDashboardCreator:
    def __init__(self, base_url="http://localhost:8088", username="admin", password="admin"):
        self.base_url = base_url
        self.username = username
        self.password = password
        self.session = requests.Session()
        self.access_token = None
        self.csrf_token = None
        self.database_id = None
        
    def authenticate(self):
        """Authenticate with Superset and get tokens"""
        print("🔐 Authenticating with Superset...")
        
        # Get CSRF token
        csrf_response = self.session.get(f"{self.base_url}/api/v1/security/csrf_token/")
        if csrf_response.status_code != 200:
            raise Exception(f"Failed to get CSRF token: {csrf_response.status_code}")
        
        self.csrf_token = csrf_response.json()["result"]
        
        # Login
        login_data = {
            "username": self.username,
            "password": self.password,
            "provider": "db",
            "refresh": True
        }
        
        headers = {"X-CSRFToken": self.csrf_token}
        login_response = self.session.post(
            f"{self.base_url}/api/v1/security/login",
            json=login_data,
            headers=headers
        )
        
        if login_response.status_code != 200:
            raise Exception(f"Login failed: {login_response.status_code}")
        
        self.access_token = login_response.json()["access_token"]
        print("✅ Authentication successful")
        
    def get_headers(self):
        """Get headers for authenticated requests"""
        return {
            "Authorization": f"Bearer {self.access_token}",
            "X-CSRFToken": self.csrf_token,
            "Content-Type": "application/json"
        }
    
    def get_or_create_database(self):
        """Get or create the Twitter analytics database connection"""
        print("🗄️ Setting up database connection...")
        
        # Check existing databases
        response = self.session.get(
            f"{self.base_url}/api/v1/database/",
            headers=self.get_headers()
        )
        
        if response.status_code == 200:
            databases = response.json()["result"]
            for db in databases:
                if db["database_name"] == "twitter_analytics":
                    self.database_id = db["id"]
                    print(f"✅ Found existing database connection (ID: {self.database_id})")
                    return
        
        # Create new database connection
        db_data = {
            "database_name": "twitter_analytics",
            "sqlalchemy_uri": "mysql://twitter_user:twitter_password@mysql:3306/twitter_analytics",
            "expose_in_sqllab": True,
            "allow_ctas": False,
            "allow_cvas": False,
            "allow_dml": False,
            "force_ctas_schema": "",
            "allow_run_async": False,
            "cache_timeout": 0,
            "impersonate_user": False,
            "encrypted_extra": "{}",
            "extra": '{"metadata_params":{},"engine_params":{},"metadata_cache_timeout":{},"schemas_allowed_for_csv_upload":[]}'
        }
        
        response = self.session.post(
            f"{self.base_url}/api/v1/database/",
            json=db_data,
            headers=self.get_headers()
        )
        
        if response.status_code == 201:
            self.database_id = response.json()["id"]
            print(f"✅ Created database connection (ID: {self.database_id})")
        else:
            raise Exception(f"Failed to create database: {response.status_code}")
    
    def create_dataset(self, table_name="tweets"):
        """Create or get dataset for the tweets table"""
        print(f"📊 Setting up dataset for {table_name} table...")
        
        # Check existing datasets
        response = self.session.get(
            f"{self.base_url}/api/v1/dataset/",
            headers=self.get_headers()
        )
        
        if response.status_code == 200:
            datasets = response.json()["result"]
            for dataset in datasets:
                if dataset["table_name"] == table_name and dataset["database"]["id"] == self.database_id:
                    print(f"✅ Found existing dataset (ID: {dataset['id']})")
                    return dataset["id"]
        
        # Create new dataset
        dataset_data = {
            "database": self.database_id,
            "table_name": table_name,
            "schema": None
        }
        
        response = self.session.post(
            f"{self.base_url}/api/v1/dataset/",
            json=dataset_data,
            headers=self.get_headers()
        )
        
        if response.status_code == 201:
            dataset_id = response.json()["id"]
            print(f"✅ Created dataset (ID: {dataset_id})")
            return dataset_id
        else:
            raise Exception(f"Failed to create dataset: {response.status_code}")
    
    def create_chart(self, chart_config):
        """Create a chart with the given configuration"""
        print(f"📈 Creating chart: {chart_config['slice_name']}")
        
        response = self.session.post(
            f"{self.base_url}/api/v1/chart/",
            json=chart_config,
            headers=self.get_headers()
        )
        
        if response.status_code == 201:
            chart_id = response.json()["id"]
            print(f"✅ Created chart '{chart_config['slice_name']}' (ID: {chart_id})")
            return chart_id
        else:
            print(f"❌ Failed to create chart: {response.status_code}")
            print(f"Response: {response.text}")
            return None
    
    def create_dashboard(self, dashboard_name, chart_ids):
        """Create dashboard with the given charts"""
        print(f"🎨 Creating dashboard: {dashboard_name}")
        
        # Create dashboard layout
        layout = self.generate_dashboard_layout(chart_ids)
        
        dashboard_data = {
            "dashboard_title": dashboard_name,
            "slug": "twitter-personality-analysis",
            "position_json": json.dumps(layout),
            "css": self.get_dashboard_css(),
            "json_metadata": json.dumps({
                "timed_refresh_immune_slices": [],
                "expanded_slices": {},
                "refresh_frequency": 30,
                "default_filters": "{}",
                "color_scheme": "supersetColors"
            })
        }
        
        response = self.session.post(
            f"{self.base_url}/api/v1/dashboard/",
            json=dashboard_data,
            headers=self.get_headers()
        )
        
        if response.status_code == 201:
            dashboard_id = response.json()["id"]
            print(f"✅ Created dashboard (ID: {dashboard_id})")
            return dashboard_id
        else:
            print(f"❌ Failed to create dashboard: {response.status_code}")
            print(f"Response: {response.text}")
            return None
    
    def generate_dashboard_layout(self, chart_ids):
        """Generate dashboard layout configuration"""
        layout = {}
        
        # Header
        layout["HEADER_ID"] = {
            "type": "HEADER",
            "id": "HEADER_ID",
            "children": [],
            "meta": {
                "width": 12,
                "height": 1,
                "text": "Twitter Personality Analysis Dashboard"
            }
        }
        
        # Charts layout (2x2 grid)
        chart_positions = [
            {"x": 0, "y": 1, "w": 6, "h": 8},  # MBTI Distribution
            {"x": 6, "y": 1, "w": 6, "h": 8},  # Tweet Volume
            {"x": 0, "y": 9, "w": 6, "h": 8},  # Verification Analysis
            {"x": 6, "y": 9, "w": 6, "h": 8}   # Recent Tweets
        ]
        
        for i, chart_id in enumerate(chart_ids[:4]):
            if i < len(chart_positions):
                pos = chart_positions[i]
                layout[f"CHART-{chart_id}"] = {
                    "type": "CHART",
                    "id": f"CHART-{chart_id}",
                    "children": [],
                    "meta": {
                        "width": pos["w"],
                        "height": pos["h"],
                        "chartId": chart_id
                    }
                }
        
        return layout
    
    def get_dashboard_css(self):
        """Get custom CSS for dashboard styling"""
        return """
        .dashboard-header {
            background: linear-gradient(90deg, #667eea 0%, #764ba2 100%);
            color: white;
            text-align: center;
            font-size: 24px;
            font-weight: bold;
            padding: 20px;
            border-radius: 8px;
            margin-bottom: 20px;
        }

        .chart-container {
            border-radius: 8px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
            margin: 10px;
        }
        """

    def get_chart_configurations(self, dataset_id):
        """Get all chart configurations for the dashboard"""
        return [
            self.get_mbti_distribution_config(dataset_id),
            self.get_tweet_volume_config(dataset_id),
            self.get_verification_analysis_config(dataset_id),
            self.get_recent_tweets_config(dataset_id)
        ]

    def get_mbti_distribution_config(self, dataset_id):
        """Configuration for MBTI personality distribution bar chart"""
        return {
            "slice_name": "MBTI Personality Distribution",
            "viz_type": "dist_bar",
            "datasource_id": dataset_id,
            "datasource_type": "table",
            "params": json.dumps({
                "metrics": ["count"],
                "groupby": ["mbti_personality"],
                "columns": [],
                "row_limit": 16,
                "order_desc": True,
                "contribution": False,
                "color_scheme": "supersetColors",
                "show_legend": True,
                "show_bar_value": True,
                "bar_stacked": False,
                "order_bars": True,
                "y_axis_format": ",d",
                "bottom_margin": "auto",
                "x_axis_label": "MBTI Personality Type",
                "y_axis_label": "Number of Tweets",
                "rich_tooltip": True,
                "show_controls": True
            }),
            "query_context": json.dumps({
                "datasource": {"id": dataset_id, "type": "table"},
                "force": False,
                "queries": [{
                    "time_range": "No filter",
                    "filters": [],
                    "extras": {"time_grain_sqla": None, "having": "", "where": ""},
                    "applied_time_extras": {},
                    "columns": ["mbti_personality"],
                    "metrics": ["count"],
                    "orderby": [["count", False]],
                    "annotation_layers": [],
                    "row_limit": 16,
                    "timeseries_limit": 0,
                    "order_desc": True,
                    "url_params": {},
                    "custom_params": {},
                    "custom_form_data": {}
                }],
                "form_data": {
                    "viz_type": "dist_bar",
                    "datasource": f"{dataset_id}__table"
                },
                "result_format": "json",
                "result_type": "full"
            })
        }

    def get_tweet_volume_config(self, dataset_id):
        """Configuration for tweet volume over time line chart"""
        return {
            "slice_name": "Tweet Volume Over Time",
            "viz_type": "line",
            "datasource_id": dataset_id,
            "datasource_type": "table",
            "params": json.dumps({
                "metrics": ["count"],
                "groupby": [],
                "columns": [],
                "granularity_sqla": "timestamp",
                "time_grain_sqla": "PT5M",
                "time_range": "No filter",
                "color_scheme": "supersetColors",
                "show_legend": True,
                "line_interpolation": "linear",
                "show_markers": True,
                "y_axis_format": ",d",
                "x_axis_label": "Time",
                "y_axis_label": "Tweet Count",
                "rich_tooltip": True,
                "show_controls": True,
                "x_axis_time_format": "%H:%M"
            })
        }

    def get_verification_analysis_config(self, dataset_id):
        """Configuration for verification status by MBTI type"""
        return {
            "slice_name": "Verification Status by MBTI",
            "viz_type": "dist_bar",
            "datasource_id": dataset_id,
            "datasource_type": "table",
            "params": json.dumps({
                "metrics": ["count"],
                "groupby": ["mbti_personality", "verified"],
                "columns": [],
                "row_limit": 50,
                "order_desc": True,
                "contribution": False,
                "color_scheme": "supersetColors",
                "show_legend": True,
                "show_bar_value": True,
                "bar_stacked": True,
                "order_bars": True,
                "y_axis_format": ",d",
                "x_axis_label": "MBTI Type",
                "y_axis_label": "User Count",
                "rich_tooltip": True
            })
        }

    def get_recent_tweets_config(self, dataset_id):
        """Configuration for recent tweets table"""
        return {
            "slice_name": "Recent Tweets Feed",
            "viz_type": "table",
            "datasource_id": dataset_id,
            "datasource_type": "table",
            "params": json.dumps({
                "metrics": [],
                "groupby": ["user_id", "mbti_personality", "tweet", "timestamp", "verified"],
                "columns": [],
                "row_limit": 20,
                "order_desc": True,
                "order_by_cols": ["timestamp"],
                "table_timestamp_format": "%Y-%m-%d %H:%M:%S",
                "page_length": 20,
                "include_search": True,
                "show_cell_bars": False,
                "color_pn": True
            })
        }

    def create_complete_dashboard(self):
        """Create the complete Twitter personality analysis dashboard"""
        print("🚀 Creating complete Twitter Personality Analysis Dashboard...")

        # Get dataset ID
        dataset_id = self.create_dataset()

        # Get chart configurations
        chart_configs = self.get_chart_configurations(dataset_id)

        # Create all charts
        chart_ids = []
        for config in chart_configs:
            chart_id = self.create_chart(config)
            if chart_id:
                chart_ids.append(chart_id)
                time.sleep(1)  # Small delay between chart creations

        if not chart_ids:
            raise Exception("No charts were created successfully")

        # Create dashboard
        dashboard_id = self.create_dashboard("Twitter Personality Analysis", chart_ids)

        if dashboard_id:
            print(f"\n🎉 Dashboard created successfully!")
            print(f"📊 Dashboard URL: {self.base_url}/superset/dashboard/{dashboard_id}/")
            print(f"📈 Created {len(chart_ids)} charts")
            return dashboard_id
        else:
            raise Exception("Failed to create dashboard")

if __name__ == "__main__":
    creator = SupersetDashboardCreator()

    try:
        # Step 1: Authenticate
        creator.authenticate()

        # Step 2: Setup database
        creator.get_or_create_database()

        # Step 3: Create complete dashboard
        dashboard_id = creator.create_complete_dashboard()

        print("\n" + "="*60)
        print("🎉 TWITTER PERSONALITY ANALYSIS DASHBOARD READY!")
        print("="*60)
        print(f"📊 Dashboard URL: {creator.base_url}/superset/dashboard/{dashboard_id}/")
        print(f"🔗 Direct Link: http://localhost:8088/superset/dashboard/{dashboard_id}/")
        print(f"👤 Login: admin / admin")
        print("\n📈 Dashboard includes:")
        print("  • MBTI Personality Distribution (Bar Chart)")
        print("  • Tweet Volume Over Time (Line Chart)")
        print("  • Verification Status by MBTI (Stacked Bar)")
        print("  • Recent Tweets Feed (Table)")
        print("\n🔄 Dashboard auto-refreshes every 30 seconds")
        print("✨ Professional styling and colors applied")

    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
