from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.options import Options
import pytest
import time

@pytest.fixture
def driver():
    options = Options()
    options.add_argument("--headless")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")

    driver = webdriver.Chrome(options=options)
    driver.implicitly_wait(5)
    yield driver
    driver.quit()

def test_homepage_loads(driver):
    driver.get("https://stage.work-experience2025.buzz")
    assert "PetClinic" in driver.title

def test_find_pet_owner(driver):
    driver.get("https://stage.work-experience2025.buzz")
    driver.find_element(By.LINK_TEXT, "FIND OWNERS").click()
    last_name = "Franklin"   # Update this if needed
    driver.find_element(By.ID, "lastName").send_keys(last_name)
    driver.find_element(By.CSS_SELECTOR, "button[type='submit']").click()
    assert last_name in driver.page_source

def test_add_new_pet(driver):
    driver.get("https://stage.work-experience2025.buzz")
    driver.find_element(By.LINK_TEXT, "FIND OWNERS").click()
    driver.find_element(By.ID, "lastName").send_keys("Franklin")
    driver.find_element(By.CSS_SELECTOR, "button[type='submit']").click()

    driver.find_element(By.LINK_TEXT, "Add New Pet").click()
    driver.find_element(By.ID, "name").send_keys("Buddy")
    driver.find_element(By.ID, "birthDate").send_keys("2023-01-10")

    pet_type_dropdown = driver.find_element(By.ID, "type")
    for option in pet_type_dropdown.find_elements(By.TAG_NAME, "option"):
        if option.text.lower() == "dog":
            option.click()
            break

    driver.find_element(By.CSS_SELECTOR, "button[type='submit']").click()
    time.sleep(1)

    assert "Buddy" in driver.page_source
