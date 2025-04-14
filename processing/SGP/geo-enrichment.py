import pandas as pd
from geopy.geocoders import Nominatim
from geopy.extra.rate_limiter import RateLimiter
import time
from typing import Tuple, Optional, Dict
import logging

class RegionLookup:
    def __init__(self, region_file: str):
        """
        Initialize the region lookup from a CSV file containing region abbreviations.
        
        Args:
            region_file (str): Path to CSV with columns: 
                             abbreviation, expanded_form, regional_town
        """
        self.region_data = pd.read_csv(region_file)
        self.abbrev_map = self._create_lookup_map()
        
    def _create_lookup_map(self) -> Dict[str, Dict[str, str]]:
        """Create a dictionary mapping abbreviations to their full information."""
        lookup = {}
        for _, row in self.region_data.iterrows():
            lookup[row['abbreviation']] = {
                'expanded': row['expanded_form'],
                'town': row['regional_town']
            }
        return lookup
    
    def get_region_info(self, abbreviation: str) -> Optional[Dict[str, str]]:
        """Get expanded region information for an abbreviation."""
        return self.abbrev_map.get(abbreviation)

class GeoEnrichment:
    def __init__(self, region_lookup: RegionLookup, user_agent: str = "geo_enrichment_script"):
        """
        Initialize the geocoding enrichment class.
        
        Args:
            region_lookup (RegionLookup): RegionLookup instance for abbreviation expansion
            user_agent (str): User agent string for Nominatim service
        """
        self.region_lookup = region_lookup
        self.geolocator = Nominatim(user_agent=user_agent)
        # Create a rate-limited version of the geocoding function
        self.geocode = RateLimiter(
            self.geolocator.geocode,
            min_delay_seconds=1,  # Respect Nominatim's usage policy
            max_retries=3
        )
        
        # Set up logging
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger(__name__)

    def get_coordinates(self, settlement: str, region_abbrev: str, 
                       country: str = "Poland") -> Optional[Tuple[float, float]]:
        """
        Get coordinates for a location using settlement and region context.
        
        Args:
            settlement (str): Settlement name to geocode
            region_abbrev (str): Region abbreviation
            country (str): Country context for better accuracy
            
        Returns:
            Tuple[float, float] or None: (latitude, longitude) if found, None if not
        """
        try:
            # Get expanded region information
            region_info = self.region_lookup.get_region_info(region_abbrev)
            
            # Try different query formats with increasing context
            queries = []
            
            # Basic query
            queries.append(f"{settlement}, {country}")
            
            if region_info:
                # Add query with expanded region name
                queries.append(f"{settlement}, {region_info['expanded']}, {country}")
                # Add query with regional town
                queries.append(f"{settlement}, {region_info['town']}, {country}")
            
            # Try each query until we get a result
            for query in queries:
                self.logger.debug(f"Trying query: {query}")
                location_data = self.geocode(query)
                
                if location_data:
                    self.logger.info(f"Found location using query: {query}")
                    return (location_data.latitude, location_data.longitude)
            
            self.logger.warning(f"Could not find coordinates for {settlement}")
            return None
            
        except Exception as e:
            self.logger.error(f"Error geocoding {settlement}: {str(e)}")
            return None

    def process_csv(self, input_file: str, output_file: str) -> None:
        """
        Process CSV file with location data and add coordinates.
        
        Args:
            input_file (str): Path to input CSV file
            output_file (str): Path to output CSV file
        """
        try:
            # Read the CSV file
            df = pd.read_csv(input_file)
            self.logger.info(f"Loaded {len(df)} records from {input_file}")
            
            # Create new columns for coordinates and expanded region info
            df['latitude'] = None
            df['longitude'] = None
            df['expanded_region'] = None
            df['regional_town'] = None
            
            # Process each row
            for idx, row in df.iterrows():
                settlement = row['Settlement']
                region_abbrev = row['Region']
                self.logger.info(f"Processing {settlement} ({region_abbrev})")
                
                # Get region information
                region_info = self.region_lookup.get_region_info(region_abbrev)
                if region_info:
                    df.at[idx, 'expanded_region'] = region_info['expanded']
                    df.at[idx, 'regional_town'] = region_info['town']
                
                # Get coordinates
                coordinates = self.get_coordinates(settlement, region_abbrev)
                if coordinates:
                    df.at[idx, 'latitude'] = coordinates[0]
                    df.at[idx, 'longitude'] = coordinates[1]
                    
                # Add a small delay to respect rate limits
                time.sleep(0.1)
            
            # Save enriched data
            df.to_csv(output_file, index=False)
            self.logger.info(f"Saved enriched data to {output_file}")
            
            # Print statistics
            total = len(df)
            geocoded = df['latitude'].notna().sum()
            self.logger.info(f"Successfully geocoded {geocoded}/{total} locations ({geocoded/total*100:.1f}%)")
            
        except Exception as e:
            self.logger.error(f"Error processing file: {str(e)}")
            raise

def main():
    # Example usage
    region_file = "sgp_abbreviations_geo.csv"  # Your region lookup file
    region_lookup = RegionLookup(region_file)
    
    enricher = GeoEnrichment(
        region_lookup=region_lookup,
        user_agent="my_geo_enrichment_script"
    )
    
    # Process the data
    input_file = "sgp_geo.csv"  # Your input CSV file
    output_file = "sgp_geo_enriched.csv"  # Output file with coordinates
    
    enricher.process_csv(input_file, output_file)

if __name__ == "__main__":
    main()
