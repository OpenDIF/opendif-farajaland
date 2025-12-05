// GraphQL client for government data exchange
export interface NDXResponseData {
  personInfo: {
    nic: string
    name: string
    fullName: string
    surname: string
    otherNames: string
    dateOfBirth: string
    birthInfo: {
      birthRegistrationNumber: string
      birthPlace: string
      district: string
    }
    sex: string // Changed to string to allow "Male"/"Female" format
    profession: string
    address: string
    district: string
    isDualCitizen: boolean
    foreignNationality?: string | null
    foreignPassportNo?: string | null
  }
}

// Simulated GraphQL query - in real implementation, this would connect to government APIs
export async function fetchGovernmentData(nicNumber: string): Promise<NDXResponseData | null> {
  // Simulate API delay
  await new Promise((resolve) => setTimeout(resolve, 2000))

  // Mock data based on NIC pattern - in real implementation, this would be actual government data
  if (nicNumber.length === 10 || nicNumber.length === 12) {
    return {
      personInfo: {
        nic: nicNumber,
        fullName: "Perera Mudiyanselage Nimal Kumara Perera",
        surname: "Perera",
        otherNames: "Nimal Kumara",
        sex: nicNumber.charAt(nicNumber.length - 2) === "1" ? "Male" : "Female",
        profession: "Software Engineer",
        address: "No. 123, Galle Road, Colombo 03",
        district: "Colombo",
        isDualCitizen: false,
        name: "Kumara Perera",
        dateOfBirth: "2020-04-03",
        birthInfo: {
          birthRegistrationNumber: "BR0895",
          birthPlace: "Colombo 03",
          district: "Colombo"
        }
      }
    }
  }

  return null
}

export async function validateNIC(nicNumber: string): Promise<boolean> {
  // Basic NIC validation for Sri Lankan format
  const oldFormat = /^[0-9]{9}[vVxX]$/
  const newFormat = /^[0-9]{12}$/

  return oldFormat.test(nicNumber) || newFormat.test(nicNumber)
}
